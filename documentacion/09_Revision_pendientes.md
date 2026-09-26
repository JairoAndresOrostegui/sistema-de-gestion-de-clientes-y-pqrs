# DTS · Revisión de pendientes resolubles

Fecha: 26 de septiembre de 2026. Esta revisión aborda dependencias y Android. Apple queda fuera por instrucción del propietario.

## Resultados ejecutados

| Comprobación | Resultado |
| --- | --- |
| Auditoría npm completa | Cero vulnerabilidades, incluyendo desarrollo. |
| Functions y reglas | 74 pruebas aprobadas; 72 existentes y 2 nuevas de compatibilidad. |
| Instalación limpia | Node 22.23.3/npm 10.9.9; instalación, auditoría y prueba del transporte aprobadas. |
| Flutter analyze | Sin problemas detectados. |
| APK release | Compilado; firma verificada con apksigner y certificado propio. |
| AAB release | Compilado; firma verificada con jarsigner. Su certificado autofirmado es el de subida Android, no un certificado público de servidor. |
| Falta de credenciales de firma | Gradle rechaza assembleRelease con un mensaje explícito. |
| FCM real Chrome | Registro, recepción, apertura, lectura, segundo plano, restauración de sesión y aislamiento web/móvil aprobados después del despliegue. |
| FCM real Android 16/API 36 | Registro nativo, recepción en primer plano, aviso del sistema en segundo plano y apertura/lectura aprobados en emulador con Google Play Services. También apertura con proceso ausente, sesión restaurada y lectura. |
| Firebase QA | Actualización completada de las cinco funciones con Node 22. |

El CI amplió la verificación con compilación Android debug y auditoría de dependencias. Se conserva el análisis, las 303 pruebas Flutter, compilación web, comprobación de plugins y pruebas de reglas/servidor. Apple no recibió cambios.

[GitHub Actions 36271189228](https://github.com/JairoAndresOrostegui/sistema-de-gestion-de-clientes-y-pqrs/actions/runs/36271189228), sobre `8b58f1c`, terminó aprobado. Confirmó análisis, pruebas Flutter, compilaciones Android/web, auditoría npm y 74 pruebas del servidor/reglas. La tarea Apple preexistente también se ejecutó automáticamente, sin cambios en esa plataforma. Se cancelaron las dos ejecuciones anteriores sustituidas por esta revisión.

La prueba Android final terminó a las 20:59:20 UTC del 26/09/2026; comprobó con `pidof` que el proceso estaba ausente antes de enviar el último aviso. Se eliminaron todos los recursos temporales. El código de servidor/firma se publicó hasta `8b58f1c`; las revisiones posteriores de documentación y automatización no cambian la aplicación desplegada.

Artefactos locales de QA con firma release: `build/app/outputs/flutter-apk/app-release.apk` y `build/app/outputs/bundle/release/app-release.aab`. Ambos usan Firebase QA. El AAB sirve para preparar la publicación en Google Play; no es un instalador directo.

SHA-256 de los archivos entregados:

- APK: `92A73814506A1AA754E6B94AB7987E8EEDD0D9B7A53AB8BB761645FC049F5CD8`.
- AAB: `2CC2FCC863FFCB74F8591BA2CF0B1684E9BA34E6E29EABBAC05668599F67A33A`.

Las primeras ejecuciones Android encontraron un bloqueo de System UI del emulador y problemas de sincronización del teclado del automatizador. Se recuperó el emulador y se verificó la entrada del correo antes de enviar el formulario. Las pruebas posteriores completaron el recorrido real. No se ocultaron fallos de negocio para obtener aprobación.

## Dependencias del servidor

Se fijó `uuid` en 11.1.1 en las dependencias de `gaxios`; en el árbol actual afecta a gaxios 6.7.1, utilizado por el SDK de Storage. El resto del árbol conserva sus versiones. La actualización automática ordinaria no eliminaba la alerta.

El transporte instalado utiliza `uuid.v4()` para los límites multipart. Se añadieron pruebas que resuelven la dependencia desde el propio SDK, comprueban carga CommonJS, UUID válido, rechazo de buffers insuficientes y envío HTTP multipart con metadatos y contenido. La declaración del override se comprobó también con una instalación limpia en Node 22/npm 10, para reproducir el entorno de Firebase; la forma inicialmente acotada por versión fallaba en ese instalador. El CI ahora rechaza vulnerabilidades de nivel moderado o superior, incluidas dependencias de desarrollo.

Referencia: [aviso de seguridad de uuid](https://github.com/advisories/GHSA-w5hq-g745-h8pq). Revisar este override cuando el SDK deje de depender de gaxios 6.7.1; no ampliar su alcance sin pruebas.

## Firma Android

La variante release dejó de usar el certificado debug. Gradle lee `android/key.properties`, excluido de Git, y detiene una compilación release si falta la configuración. `android/key.properties.example` documenta los campos sin credenciales.

Se creó una clave RSA de 3072 bits, alias `dts-upload`, válida por 10000 días. Se conserva en `C:\Users\Jairo\.dts-signing\android`, junto a una copia de su configuración. Esa carpeta restringe acceso al usuario actual y SYSTEM. Las contraseñas se generan aleatoriamente y no se imprimen. `scripts/setup-android-signing.cjs` permite preparar otro entorno nuevo y se niega a reemplazar una clave existente.

**Respaldo necesario:** conservar una copia segura y cifrada de esa carpeta. Para compilar en otro equipo, restaurar la clave y crear `android/key.properties` con la ruta local correcta. No enviar claves o contraseñas al repositorio ni junto al APK. Crear otra clave arbitraria impediría actualizar instalaciones firmadas con la anterior.

Se registraron las huellas SHA-1 y SHA-256 del certificado en Firebase y se actualizó `google-services.json`, incluido el cliente OAuth Android correspondiente.

La firma local no inscribe la aplicación en Google Play. La inscripción, cuenta de desarrollador, fichas y Play App Signing requieren acceso a Play Console. Al activar Play App Signing, registrar también el certificado de firma de Google Play en Firebase. Referencia: [distribución Android con Flutter](https://docs.flutter.dev/deployment/android).

## Prueba nativa reproducible

`node scripts/qa-android-notifications.cjs` utiliza un emulador Android con servicios de Google, la app instalada y la sesión local de Firebase CLI. `ANDROID_SERIAL` permite seleccionar el emulador. El script rechaza teléfonos físicos porque limpia los datos de la aplicación del dispositivo seleccionado.

La prueba crea una cuenta temporal comercial, inicia sesión por la interfaz nativa y comprueba FCM real en primer plano, segundo plano y apertura con el proceso terminado. Los eventos tienen un destinatario temporal explícito; no se envían avisos de prueba a clientes reales. El bloque de limpieza elimina cuenta, destinos, tokens y eventos. El informe en `artifacts/qa-android-notifications.json` conserva únicamente resultados, sin credenciales ni tokens.

## Límites que siguen requiriendo recursos externos

- Validación en teléfonos físicos y redes reales; un emulador no sustituye esa matriz.
- Publicación en Google Play, con acceso a la cuenta de desarrollador.
- Correo de negocio, con proveedor, dominio y credenciales configurados.
- Prueba de carga de producción, con volumen objetivo y entorno acordados.
- Garantías de entrega sujetas a permisos y políticas del sistema. FCM no garantiza entrega exactamente una vez.

La idempotencia general de operaciones de negocio sigue siendo una ampliación pendiente; no confundirla con la protección contra duplicados de la bandeja y las transacciones de dispositivos ya implementadas. El alcance adicional del pliego está separado en `docs/PROGRESS.md`.
