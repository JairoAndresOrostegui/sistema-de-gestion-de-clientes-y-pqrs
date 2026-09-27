# DTS · Gestión de clientes, proyectos y PQRS

Aplicación **Flutter** para web, Android e iOS, con Firebase Authentication, Firestore, Storage y Cloud Functions TypeScript. Interfaz en español, zona horaria Bogotá y COP. Identidad de **Desarrollo & Tecnología Santander**.

- QA: https://sistema-de-gestion-y-pqrs.web.app
- Repositorio: https://github.com/JairoAndresOrostegui/sistema-de-gestion-de-clientes-y-pqrs
- Administrador principal: `jairoandresorostegui@gmail.com`, acceso con Google.
- [Estado real y pendientes](docs/PROGRESS.md) · [Manual](docs/USER_GUIDE.md) · [Modelo y seguridad](docs/ARCHITECTURE.md) · [Despliegue](docs/DEPLOYMENT.md).
- [Auditoría ampliada de concurrencia, navegación y presentación](docs/QA_AUDIT.md): pruebas, correcciones, evidencia y límites.
- [Pruebas físicas y acta de decisión](documentacion/10_Pruebas_fisicas.md): recorrido por rol, dispositivos y criterios de salida.

Esta entrega conecta los recorridos principales a persistencia real. Los pendientes del alcance ampliado y de producción están declarados en PROGRESS; no se presentan como terminados. QA comienza sin datos de clientes ficticios; los fixtures de pruebas viven en emuladores.

## Ejecutar

Requisitos: Flutter 3.47.5 / Dart 3.13.4, Node 22, Java 21, Firebase CLI autenticado. Android SDK 36 para compilar móvil. Xcode y macOS para iOS.

```powershell
flutter pub get
npm --prefix functions ci
npm --prefix functions run build
flutter run -d chrome --web-port 7357
```

La configuración pública QA de las tres plataformas está en `lib/firebase_options.dart`. No es necesario aportar otro ID Firebase. Nunca colocar credenciales administrativas en Dart o en assets.

## Pruebas

```powershell
flutter analyze
flutter test
npm --prefix functions run lint
npm --prefix functions test

# Windows: comillas en las listas con comas.
$env:DEBUG=''
$env:FUNCTIONS_DISCOVERY_TIMEOUT='60'
$env:FUNCTIONS_EMULATOR='true'
$env:GCLOUD_PROJECT='demo-dts-gestion'
firebase emulators:exec --only 'auth,firestore,functions,storage' --project demo-dts-gestion 'npm --prefix functions test'
```

Las pruebas de reglas y flujo se omiten intencionalmente sin emuladores; para validar seguridad debe ejecutarse el comando completo. Los tests usan cuentas `example.test` y credenciales exclusivamente locales. No apuntar los fixtures a un proyecto real.

Para desarrollo interactivo, iniciar emuladores con el **mismo ID configurado en el cliente**:

```powershell
firebase emulators:start --only 'auth,firestore,functions,storage' --project sistema-de-gestion-y-pqrs
flutter run -d chrome --web-port 7357 --dart-define=USE_EMULATORS=true
# Android emulador: añadir --dart-define=EMULATOR_HOST=10.0.2.2
```

## Compilar y publicar en QA

```powershell
flutter build web --release
flutter build apk --debug
npm --prefix functions run build
firebase deploy --project qa --only 'firestore,storage,functions,hosting'
```

APK universal: `build/app/outputs/flutter-apk/app-debug.apk`, disponible para pruebas físicas en `https://sistema-de-gestion-y-pqrs.web.app/downloads/dts-qa-debug.apk` tras el despliegue QA. No contiene firma de distribución de Play Store. iOS: abrir `ios/Runner.xcworkspace` en macOS y seguir DEPLOYMENT.

`scripts/browser-smoke.cjs` comprueba el inicio real en Chrome y captura vistas de escritorio/móvil. Ejecutar un servidor estático de `build/web` en 7357 y luego `node scripts/browser-smoke.cjs`; o pasar como argumento la URL QA. Las capturas quedan en `artifacts/`, excluido de Git.

## Importar desde una carpeta local

```powershell
npm --prefix functions run build
node scripts/import-local.cjs 'D:\ruta\del\proyecto' 'local-import-preview.json'
```

Revisar el JSON y cargarlo desde **Enlazar proyecto → Importar archivo local**. La CLI no sigue symlinks ni envía archivos a Internet. Limita archivos, tamaño y rutas; excluye secretos conocidos y dependencias generadas. La revisión humana sigue siendo obligatoria.

## Configuración externa pendiente

1. GitHub App privada: App ID, instalación y clave privada en Secret Manager para activar repositorios privados.
2. Proveedor de correo si se desea enviar avisos por email. La bandeja personal y el envío push FCM están implementados, con destinos separados web/celular y trazabilidad de cada etapa de atención.
3. Equipo Apple, firma iOS y clave APNs en Firebase; cuentas de tiendas y Play App Signing. La firma release Android del PC anterior debe restaurarse desde su respaldo; ver [revisión de pendientes](documentacion/09_Revision_pendientes.md).

El bootstrap, identidades OAuth móviles, Storage CORS y proyecto Firebase QA ya están configurados. No hace falta registrar públicamente un primer administrador ni compartir contraseñas.

## Documentación y notificaciones

La [carpeta de documentación](documentacion/00_Indice.md) contiene el documento técnico, la descripción funcional para entregar al cliente, los cinco manuales por rol y el reporte de validación. `node scripts/sync-documentation.cjs` la copia junto a la carpeta del prompt, en `../documentacion`.

En **Mi cuenta** se registra el último navegador y la última aplicación celular por separado y se activa push. **Notificaciones** conserva bandeja personal y resultados de envío. La campana del detalle de una solicitud abre su trazabilidad. Los push no incluyen detalles privados en la pantalla bloqueada.

Funciones nuevas: `notificationDispatch`, `notificationLegacy` y `notificationRetry`. La migración de avisos antiguos usa `node scripts/migrate-notifications.cjs` y conserva historia sin reenviar push retroactivos. Ver [operación técnica](documentacion/01_Tecnico.md) para permisos, reintentos, FCM y límites de confirmación.

Android release requiere restaurar la clave privada de firma usada en el PC anterior; `android/key.properties` apunta a esa clave pero el archivo `.jks` no vino con el proyecto. No generar otra sin un plan de actualización. La prueba nativa reproducible es `node scripts/qa-android-notifications.cjs` sobre un emulador desechable con Google Play Services; limpia los datos de la app y utiliza una cuenta temporal.
