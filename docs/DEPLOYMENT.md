# Configuración y despliegue

## Entorno QA existente

- Firebase: `sistema-de-gestion-y-pqrs`, alias `qa`.
- Hosting: `https://sistema-de-gestion-y-pqrs.web.app`.
- Región de funciones: `us-central1`; Firestore: `nam5`.
- Android: `co.com.dts.dts_gestion`.
- iOS: `co.com.dts.dtsGestion`, deployment target 15.
- Propietario explícito: `jairoandresorostegui@gmail.com`.

Los identificadores de cliente Firebase de `firebase_options.dart` y los archivos móviles no son credenciales administrativas. Las reglas protegen los datos. No se incluyen claves de cuentas de servicio, contraseñas ni tokens GitHub.

## Bootstrap

`node scripts/provision-qa.cjs` usa la sesión IAM ya autenticada del Firebase CLI en Windows. El script está restringido al ID de QA y al correo propietario indicado. Busca o crea el UID en Auth y escribe un perfil owner. **No marca el correo como verificado**, no crea una contraseña y no permite que un registro público reclame el rol. Para iniciar sesión, usar Google con esa cuenta. No ejecutar contra producción ni modificar el correo sin una decisión administrativa explícita.

El script es de provisión local; no se publica como endpoint. Para otros sistemas, usar Admin SDK con Application Default Credentials e IAM mínimo siguiendo el mismo procedimiento. No copiar refresh tokens a archivos de entorno del frontend.

## GitHub App

1. Crear una GitHub App privada. Permisos de repositorio: Metadata read y Contents read. Instalar solamente en los repositorios elegidos.
2. Guardar la clave privada en Google Secret Manager. Inyectarla como `GITHUB_APP_PRIVATE_KEY` en la función y el ID como `GITHUB_APP_ID`. El adaptador `installationToken` firma JWT de corta duración y pide tokens de instalación con Contents read.
3. Para activar oficialmente la integración, declarar el secreto en `onCall({secrets:[...]})`, desplegar con ese secreto y verificar en emulador/QA sin registrarlo en logs. La versión inicial no requiere ni liga un secreto inexistente para poder desplegar el resto del sistema.
4. Escribir la URL y el ID de instalación en **Enlazar proyecto**. Nunca pegar tokens en la aplicación.
5. La sincronización actual es manual. Webhook firmado y sincronización programada permanecen pendientes; cualquier actualización funcional requiere revisión humana.

## iOS

En macOS con Xcode: `flutter pub get`, `flutter build ios --no-codesign` para verificación inicial; después seleccionar el equipo Apple y configurar firma en Runner. Para distribuir: `flutter build ipa` y envío con la cuenta Apple correspondiente. El bundle ID y esquema de retorno Google ya están configurados. No se ha generado un IPA desde Windows.

## Android

`flutter build apk --debug` produce `build/app/outputs/flutter-apk/app-debug.apk` para QA. La huella SHA-1 del certificado debug de este equipo se registró en Firebase. La clave de release/Play App Signing no se configura con una clave inventada; crear una clave propia, registrarla en Firebase y protegerla fuera de Git antes de publicar en Play Store. El build release del scaffold utiliza firma debug hasta configurar la distribución.

## Operación

Las funciones establecen límite de instancias. QA tiene facturación habilitada y usar Firestore/Functions/Storage genera consumo. No hay proveedor de email conectado. Los recordatorios se guardan internamente con `emailStatus: not_configured`. El correo no se simula.

Para habilitar CI de despliegue, crear federación OIDC de GitHub a Google Cloud y otorgar acceso exclusivamente a QA. No almacenar tokens de larga duración en el repositorio. Los workflows incluidos ejecutan comprobaciones; la publicación inicial se hace con Firebase CLI autenticado.
