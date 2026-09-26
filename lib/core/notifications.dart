import 'dart:async';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// Stores an installation identifier, never a hardware identifier or a push token.
class DeviceNotifications {
  static final incoming = ValueNotifier<Json?>(null);
  static final status = ValueNotifier<String>('Notificaciones sin activar');
  static String? _uid;
  static StreamSubscription<String>? _tokens;
  static StreamSubscription<RemoteMessage>? _messages, _opened;
  static String get slot => kIsWeb ? 'web' : 'mobile';

  static String _uuid() {
    final r = Random.secure();
    final bytes = List.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static Future<void> login(String uid) async {
    if (_uid == uid && Api.clientContext != null) return;
    await _cancel();
    Api.clientContext = null;
    _uid = uid;
    var phase = 'preferences';
    try {
      final prefs = await SharedPreferences.getInstance();
      final installation = prefs.getString('dts.installation') ?? _uuid();
      await prefs.setString('dts.installation', installation);
      phase = 'device_metadata';
      final info = DeviceInfoPlugin();
      String platform = 'web', label = 'Navegador web';
      if (kIsWeb) {
        final web = await info.webBrowserInfo;
        label = '${web.browserName.name} · ${web.platform ?? 'Web'}';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        platform = 'android';
        final android = await info.androidInfo;
        label = '${android.manufacturer} ${android.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        platform = 'ios';
        final ios = await info.iosInfo;
        label = '${ios.model} · iOS ${ios.systemVersion}';
      } else {
        status.value = 'Este sistema no admite notificaciones móviles';
        return;
      }
      phase = 'server_registration';
      final registered = await Api.call('registerDevice', {
        'slot': slot,
        'platform': platform,
        'label': label,
        'installationId': installation,
      });
      if (_uid != uid) return;
      Api.clientContext = {'sessionId': registered['sessionId']};
      status.value =
          'Dispositivo registrado. Activa las notificaciones en Mi cuenta.';
      final notification = Uri.base.queryParameters['notification'];
      if (notification != null) {
        incoming.value = {'id': notification, 'opened': true};
      }
      if (const bool.fromEnvironment('USE_EMULATORS')) return;
      unawaited(_connect(uid));
    } catch (error) {
      debugPrint(
        'device.registration.failed phase=$phase type=${error.runtimeType} error=$error',
      );
      status.value =
          'No se pudo completar el registro push. Reintenta en Mi cuenta.';
    }
  }

  static Future<void> _connect(String uid) async {
    if (_uid != uid) return;
    try {
      final messaging = FirebaseMessaging.instance;
      _tokens = messaging.onTokenRefresh.listen(
        (token) {
          unawaited(_saveToken(token));
        },
        onError: (Object _) {
          status.value = 'No se pudo actualizar el destino push';
        },
      );
      _messages = FirebaseMessaging.onMessage.listen((message) {
        unawaited(_receive(message, opened: false));
      });
      _opened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        unawaited(_receive(message, opened: true));
      });
      await enable(requestPermission: false);
      final initial = await messaging.getInitialMessage();
      if (initial != null) await _receive(initial, opened: true);
    } catch (_) {
      status.value =
          'No se pudo completar el registro push. Reintenta en Mi cuenta.';
    }
  }

  static Future<void> enable({bool requestPermission = true}) async {
    try {
      if (Api.clientContext == null) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) await login(uid);
        if (Api.clientContext == null) return;
      }
      final messaging = FirebaseMessaging.instance;
      if (!await messaging.isSupported()) {
        await _saveToken(null, permission: 'unavailable');
        status.value =
            'Este navegador no admite push. Tu bandeja sigue disponible.';
        return;
      }
      final settings = requestPermission
          ? await messaging.requestPermission()
          : await messaging.getNotificationSettings();
      final permission = settings.authorizationStatus.name;
      if (!['authorized', 'provisional'].contains(permission)) {
        await _saveToken(null, permission: permission);
        status.value = permission == 'denied'
            ? 'Permiso bloqueado. Habilítalo en los ajustes del navegador o celular.'
            : 'Activa las notificaciones para recibir avisos en este dispositivo.';
        return;
      }
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          await messaging.getAPNSToken() == null) {
        await _saveToken(null, permission: permission);
        status.value = 'iOS aún no tiene un destino APNs disponible.';
        return;
      }
      const vapid = String.fromEnvironment('FCM_VAPID_KEY');
      final token = await messaging
          .getToken(vapidKey: vapid.isEmpty ? null : vapid)
          .timeout(const Duration(seconds: 20));
      await _saveToken(token, permission: permission);
    } catch (_) {
      status.value =
          'No se pudo activar push. Revisa la conexión y vuelve a intentar.';
    }
  }

  static Future<void> _saveToken(
    String? token, {
    String permission = 'authorized',
  }) async {
    final context = Api.clientContext;
    if (context == null) return;
    try {
      final result = await Api.call('updateDeviceToken', {
        ...context,
        'token': token,
        'permission': permission,
      });
      status.value = result['superseded'] == true
          ? 'Otro dispositivo de este tipo es ahora el último registrado.'
          : token != null
          ? 'Notificaciones activas en este dispositivo'
          : 'Destino registrado sin push activo';
    } catch (_) {
      status.value = 'No se pudo guardar el destino push. Vuelve a intentar.';
    }
  }

  static Future<void> _receive(
    RemoteMessage message, {
    required bool opened,
  }) async {
    final id = message.data['notificationId'];
    if (id == null || _uid == null) return;
    try {
      await Api.call('notificationReceipt', {
        'id': id,
        'kind': opened ? 'opened' : 'received',
      });
      incoming.value = {'id': id, 'opened': opened};
    } catch (_) {
      /* A push for a revoked account must never open its content. */
    }
  }

  static Future<void> _cancel() async {
    await _tokens?.cancel();
    await _messages?.cancel();
    await _opened?.cancel();
    _tokens = null;
    _messages = null;
    _opened = null;
    incoming.value = null;
  }

  static Future<void> signOut() async {
    try {
      if (Api.clientContext != null) {
        await Api.call(
          'unregisterDevice',
          Api.clientContext!,
        ).timeout(const Duration(seconds: 8));
      }
    } catch (_) {
      // Still revoke the local FCM endpoint if the callable is temporarily offline.
      try {
        await FirebaseMessaging.instance.deleteToken().timeout(
          const Duration(seconds: 5),
        );
      } catch (_) {}
    } finally {
      await _cancel();
      _uid = null;
      Api.clientContext = null;
      status.value = 'Notificaciones sin activar';
      await FirebaseAuth.instance.signOut();
    }
  }
}
