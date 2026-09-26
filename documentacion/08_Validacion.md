# DTS · Validación de la entrega de dispositivos y notificaciones

Fecha: 2026-09-26. Entorno de ejecución: Windows, Firebase QA y emuladores Firebase. Este registro describe pruebas ejecutadas; no certifica ausencia de cualquier error posible.

## Evidencia automatizada

| Verificación | Resultado |
| --- | --- |
| `flutter analyze` | Sin problemas detectados. |
| `flutter test` | 303 pruebas aprobadas. |
| Nuevas pruebas visuales | 19: dispositivos con nombres largos, bandeja desplegada, trazabilidad desplegada y recuperación de error. |
| Tamaños nuevos | 320×568, 390×844, 768×1024, 1440×900, 844×390 y 390×844 con texto al 200 %. |
| Pruebas previas de interfaz | Pantallas, formularios, navegación por rol, teclado, calendario, estados vacíos, errores de red y cambios rápidos de empresa. |
| Functions y reglas | 72 pruebas aprobadas con Firebase Auth, Firestore, Functions y Storage en emuladores. |
| Web | Compilación release JavaScript completada. |
| Android | APK debug compilado correctamente. El compilador Java informó uso de API deprecada en dependencias; no impidió la compilación. |
| Push real QA en Chrome | Aprobado: registro FCM, destinos separados, función desplegada, recepción, apertura, lectura, reemplazo concurrente y limpieza de identidad temporal. También recepción en segundo plano mediante service worker y apertura por enlace con sesión restaurada. |
| Navegación real QA | 75 visitas de pantalla en cinco tamaños; sin errores/advertencias de consola durante operación normal. El fallo de red provocado mostró error y recuperó datos al reintentar. |
| CI iOS | Compilación release sin firma aprobada en macOS. No equivale a distribución por App Store ni a prueba push en iPhone físico. |

## Casos de notificaciones cubiertos

Registro separado de web/celular; sustitución por nuevo acceso; accesos simultáneos; rechazo de refrescos y cierres obsoletos; rechazo de sesión ajena; token reutilizado por otra cuenta; privacidad de tokens; audiencias pública/interna/técnica; alcance de solicitante; evento atómico con transacción; duplicación de ejecución; datos generales en pantalla bloqueada; aceptación del proveedor sin inventar recepción; lectura concurrente e idempotente; revocación; reintentos; token inválido; permisos denegados; histórico sin reenvío y rotación de token durante un fallo.

El emulador no emula FCM. Las pruebas de envío del servidor inyectan un proveedor controlado. El script `qa-notifications.cjs` verifica por separado el proveedor real con identidad y destino temporales.

La prueba real ampliada de push terminó el 26/09/2026 a las 18:14:12 UTC. Se ejecutó con un perfil regular temporal de Chrome, porque incógnito y la supresión de red en segundo plano del automatizador impiden probar el servicio push. En segundo plano se comprobó el aviso almacenado por el service worker sin fabricar un recibo de primer plano. Después se abrió el enlace, se restauró la sesión y se confirmó la lectura. El script conserva únicamente estados de prueba, sin tokens en el reporte. La migración histórica se ejecutó y no encontró avisos legados pendientes en QA.

## Publicación y comprobación final

Código de aplicación publicado en Git con `282b177`; revisión de pruebas y CI `c21d1ba`. [GitHub Actions 36261520306](https://github.com/JairoAndresOrostegui/sistema-de-gestion-de-clientes-y-pqrs/actions/runs/36261520306) terminó con `verify` e `ios-check` aprobados. Los cambios posteriores del reporte y del script de comprobación en segundo plano no modifican el código de la aplicación desplegada.

Firebase QA confirmó las cinco funciones en estado `ACTIVE`: `api`, `renewalReminders`, `notificationDispatch`, `notificationLegacy` y `notificationRetry`. Hosting quedó publicado en https://sistema-de-gestion-y-pqrs.web.app. Firestore/Storage e índices fueron desplegados. Los scripts de comprobación eliminaron sus identidades, destinos, eventos y entregas temporales.

APK locales: `build/app/outputs/flutter-apk/app-debug.apk`, `app-arm64-v8a-debug.apk`, `app-armeabi-v7a-debug.apk` y `app-x86_64-debug.apk`. Todos son de QA y firma debug. No había teléfono Android ni iPhone conectado en el entorno de trabajo; se verificaron compilación, interfaz y servidor, y el push real se verificó en Chrome.

## Correcciones derivadas de pruebas

Los encabezados extensos de la bandeja y trazabilidad se resumieron visualmente para que el control de despliegue permanezca utilizable con texto al 200 %. El contenido completo se conserva al abrir. Se eliminó una advertencia del analizador sobre acceso a un miembro exclusivo de pruebas y se ajustaron bloques de control. La configuración Vitest se identifica como módulo ESM para evitar su advertencia de carga futura.

La prueba real detectó un registro web de plugins obsoleto en la caché incremental de Flutter. Se regeneró la compilación y se añadió `scripts/check-web-plugins.cjs` al flujo CI para detectar la ausencia de preferencias, información del dispositivo o mensajería antes de publicar. También se separó la inicialización push del acceso para que una demora de FCM no bloquee el portal.

CI detectó tres avisos de estilo en las nuevas pruebas visuales; se corrigieron. Se actualizaron las acciones de infraestructura para usar las versiones vigentes con runtime Node 24 y se fijó Ubuntu 24.04 para evitar cambios automáticos de imagen. Referencias: [checkout](https://github.com/actions/checkout), [setup-node](https://github.com/actions/setup-node), [setup-java](https://github.com/actions/setup-java), [upload-artifact](https://github.com/actions/upload-artifact).

## Configuración pendiente y límites

- Auditoría de dependencias de ejecución: dos alertas moderadas transitivas (`gaxios` y `uuid`), ninguna alta ni crítica. Se conservan documentadas; no se impuso una versión mayor mediante un override sin validar compatibilidad del SDK.
- iOS: equipo Apple, firma de la aplicación, clave APNs en Firebase y validación en iPhone real. El código, bundle ID, entitlement push y modo remoto están preparados.
- Android: firma de distribución/Play App Signing y prueba push en un teléfono físico. El APK debug es para QA.
- Navegadores: requieren HTTPS, permiso y soporte push; las políticas del navegador/sistema pueden impedir entrega. Revisar cuál es el último destino de cada tipo.
- Correo externo de negocio: no hay proveedor configurado; los avisos usan bandeja y FCM.
- Los eventos y FCM pueden repetir entrega tras un fallo entre el envío y su confirmación. Los IDs de bandeja son deterministas y los push usan tags/collapse IDs, pero no se promete exactamente una entrega.
- No se ejecutó una prueba de carga masiva de producción ni una matriz completa de dispositivos físicos. La compilación y los tests no sustituyen esas validaciones.
- Las operaciones de negocio cuya respuesta se pierde deben comprobarse en el historial antes de repetirlas. Esta entrega no añade una clave general de idempotencia para toda acción del sistema.

Los logs completos y capturas locales se guardan en `build/` y `artifacts/`, excluidos de Git para evitar ruido y datos temporales. El repositorio conserva las pruebas reproducibles, scripts, configuración y este reporte. La auditoría de QA puede contener referencias a identidades sintéticas ya eliminadas.
