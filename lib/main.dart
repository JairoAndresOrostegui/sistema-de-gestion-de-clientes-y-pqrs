import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'features/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? error;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (const bool.fromEnvironment('USE_EMULATORS')) {
      const host = String.fromEnvironment(
        'EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).useFunctionsEmulator(host, 5001);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    }
  } catch (e) {
    error = e;
  }
  runApp(DtsApp(startupError: error));
}

class DtsApp extends StatelessWidget {
  const DtsApp({super.key, this.startupError});
  final Object? startupError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'DTS · Gestión y PQRS',
    theme: dtsTheme(),
    locale: const Locale('es', 'CO'),
    supportedLocales: const [Locale('es', 'CO')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: startupError == null
        ? const AuthGate()
        : const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No fue posible conectar con DTS. Revisa tu conexión y vuelve a abrir la aplicación.',
                ),
              ),
            ),
          ),
  );
}
