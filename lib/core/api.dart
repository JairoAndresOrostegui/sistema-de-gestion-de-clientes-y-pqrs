import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

typedef Json = Map<String, dynamic>;
Json jsonMap(dynamic data) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
List<Json> jsonList(dynamic data) =>
    (data as List? ?? []).map(jsonMap).toList();

class Api {
  /// Replaces only the transport in widget tests; production uses Firebase.
  @visibleForTesting
  static Future<Json> Function(String action, Json data)? testTransport;

  static Future<Json> call(String action, [Json data = const {}]) async {
    if (testTransport != null) return testTransport!(action, data);
    final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable(
          'api',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        )
        .call({'action': action, 'data': data});
    return jsonMap(result.data);
  }

  static Future<Json> list(String collection, [Json filters = const {}]) =>
      call('list', {'collection': collection, ...filters});
}

class Session extends ChangeNotifier {
  Session(this.profile);
  final Json profile;
  List<Json> companies = [], projects = [];
  String? companyId, projectId;
  int _projectRequest = 0;
  bool get staff => ['owner', 'commercial'].contains(role);
  bool get owner => role == 'owner';
  bool get technical => owner || role == 'technician';
  String get role => profile['role'] as String;
  String get uid => profile['uid'] as String;
  bool get canManage =>
      staff || (profile['permissions'] as List? ?? []).contains('manage');
  String get roleName => labels[role] ?? role;
  Json get filters => {
    if (companyId != null) 'companyId': companyId,
    if (projectId != null) 'projectId': projectId,
  };
  Future<void> load() async {
    if (staff) {
      companies = jsonList(
        (await Api.list('companies', {'limit': 100}))['items'],
      );
    } else {
      final memberships = jsonList(
        (await Api.list('memberships', {'limit': 100}))['items'],
      );
      companies = [];
      for (final m in memberships) {
        companies.addAll(
          jsonList(
            (await Api.list('companies', {
              'companyId': m['companyId'],
            }))['items'],
          ),
        );
      }
    }
    if (companyId != null && !companies.any((c) => c['id'] == companyId)) {
      companyId = null;
    }
    if (!staff && companyId == null && companies.isNotEmpty) {
      companyId = companies.first['id'];
    }
    await loadProjects();
    notifyListeners();
  }

  Future<void> loadProjects() async {
    final request = ++_projectRequest;
    final selectedCompany = companyId;
    late List<Json> result;
    try {
      result = (staff || selectedCompany != null)
          ? jsonList(
              (await Api.list('projects', {
                'limit': 100,
                'companyId': ?selectedCompany,
              }))['items'],
            )
          : [];
    } catch (_) {
      if (request != _projectRequest || selectedCompany != companyId) return;
      rethrow;
    }
    if (request != _projectRequest || selectedCompany != companyId) return;
    projects = result;
    if (!projects.any((p) => p['id'] == projectId)) projectId = null;
    if (!staff && projectId == null && projects.isNotEmpty) {
      projectId = projects.first['id'];
    }
  }

  Future<void> selectCompany(String? id) async {
    companyId = id;
    projectId = null;
    projects = [];
    notifyListeners();
    await loadProjects();
    notifyListeners();
  }

  void selectProject(String? id) {
    projectId = id;
    notifyListeners();
  }

  String companyName(dynamic id) =>
      companies.where((c) => c['id'] == id).firstOrNull?['name'] ?? 'Empresa';
  String projectName(dynamic id) =>
      projects.where((c) => c['id'] == id).firstOrNull?['name'] ?? 'Proyecto';
}

String readableError(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'internal' => 'No se pudo completar la operación. Intenta nuevamente.',
      'unavailable' =>
        'No se pudo conectar con el servicio. Revisa tu conexión e intenta nuevamente.',
      'deadline-exceeded' =>
        'La operación tardó demasiado. Intenta nuevamente.',
      _ => error.message ?? 'No se pudo completar la operación.',
    };
  }
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Revisa el correo y la contraseña.',
      'email-already-in-use' =>
        'Este correo ya tiene una cuenta. Inicia sesión o recupera tu contraseña.',
      'account-exists-with-different-credential' =>
        'Este correo usa otro proveedor. Inicia sesión con tu método habitual y vincula Google desde tu cuenta.',
      'popup-closed-by-user' ||
      'cancelled-popup-request' => 'Se canceló el inicio de sesión.',
      'popup-blocked' =>
        'Permite las ventanas emergentes para iniciar sesión con Google.',
      'too-many-requests' => 'Hay demasiados intentos. Espera unos minutos.',
      'network-request-failed' =>
        'No hay conexión. Revisa tu red e intenta nuevamente.',
      'weak-password' => 'Usa una contraseña de al menos 8 caracteres.',
      'invalid-email' => 'Escribe un correo válido.',
      _ => 'No se pudo autenticar tu cuenta (${error.code}).',
    };
  }
  return 'No se pudo completar la operación. Revisa la conexión e intenta nuevamente.';
}

String displayDate(dynamic value, {bool time = false}) {
  if (value == null || value.toString().isEmpty) return '—';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  final d = value.toString().contains('T')
      ? parsed.toUtc().subtract(const Duration(hours: 5))
      : parsed;
  return DateFormat(
    time ? 'd MMM yyyy · HH:mm' : 'd MMM yyyy',
    'es_CO',
  ).format(d);
}

DateTime? parseCalendarDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final date = DateTime.tryParse(value);
  return date != null && date.toIso8601String().substring(0, 10) == value
      ? date
      : null;
}

String money(dynamic value, [String currency = 'COP']) => NumberFormat.currency(
  locale: 'es_CO',
  name: currency,
  decimalDigits: 0,
).format(value is num ? value : 0);
String label(dynamic key) =>
    labels[key?.toString()] ?? key?.toString().replaceAll('_', ' ') ?? '—';
const labels = <String, String>{
  'owner': 'Propietario',
  'commercial': 'Comercial / Operativo',
  'client': 'Cliente',
  'technician': 'Técnico',
  'reader': 'Lector',
  'nuevo': 'Nuevo',
  'clasificacion': 'En clasificación',
  'esperando_cliente': 'Esperando cliente',
  'primer_nivel': 'Primer nivel',
  'escalado': 'Escalado a técnico',
  'analisis': 'En análisis',
  'ejecucion': 'En ejecución',
  'resuelto': 'Resuelto',
  'cerrado': 'Cerrado',
  'reabierto': 'Reabierto',
  'cancelado': 'Cancelado',
  'baja': 'Baja',
  'media': 'Media',
  'alta': 'Alta',
  'critica': 'Crítica',
  'bajo': 'Bajo',
  'medio': 'Medio',
  'alto': 'Alto',
  'critico': 'Crítico',
  'peticion': 'Petición',
  'queja': 'Queja',
  'reclamo': 'Reclamo',
  'sugerencia': 'Sugerencia',
  'incidente': 'Incidente / Error',
  'soporte': 'Soporte',
  'consulta': 'Consulta',
  'capacitacion': 'Capacitación',
  'mejora': 'Cambio / Mejora',
  'public': 'Visible al cliente',
  'internal': 'Nota interna DTS',
  'technical': 'Nota técnica reservada',
  'fuera_cobertura': 'Fuera de cobertura',
  'cubierto': 'Con cobertura',
  'negociacion': 'Negociación',
  'contratado': 'Contratado',
  'desarrollo': 'Desarrollo',
  'implementacion': 'Implementación',
  'activo': 'Activo',
  'mantenimiento': 'Mantenimiento',
  'suspendido': 'Suspendido',
  'finalizado': 'Finalizado',
  'prospecto': 'Prospecto',
  'inactivo': 'Inactivo',
  'disponible': 'Disponible',
  'planificado': 'Planificado',
  'retirado': 'Retirado',
  'pendiente': 'Pendiente',
  'en_curso': 'En curso',
  'completado': 'Completado',
  'vencido': 'Vencido',
  'renovado': 'Renovado',
  'borrador': 'Borrador',
  'venta': 'Venta',
  'dominio': 'Dominio',
  'hosting': 'Hosting',
  'otro': 'Otro',
  'tarea': 'Tarea',
  'hito': 'Hito',
  'visita': 'Visita',
  'reunion': 'Reunión',
  'despliegue': 'Despliegue',
  'compromiso': 'Compromiso',
  'ingreso': 'Ingreso',
  'gasto': 'Gasto',
  'participacion': 'Participación',
};
