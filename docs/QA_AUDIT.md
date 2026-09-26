# Auditoría ampliada de QA — 26 de septiembre de 2026

La primera entrega tenía 42 pruebas y una revisión visual limitada. Esta auditoría amplía la cobertura; **no garantiza ausencia de errores ni equivale a probar todas las combinaciones posibles**.

## Evidencia automatizada

| Revisión | Resultado y alcance |
| --- | --- |
| Análisis Flutter | Sin incidencias |
| Pruebas Flutter | 284 aprobadas; incluye parametrizaciones por pantalla/tamaño, no 284 flujos de negocio diferentes |
| Backend y reglas Firebase | 50 aprobadas en emuladores Auth, Firestore, Functions y Storage |
| Matriz de presentación | 20 pantallas con datos ficticios extensos, 12 formularios y acceso en 7 configuraciones: 320×568, 390×844, 768×1024, 1024×768, 1440×900, 844×390 y 390×844 con texto al 200% |
| Navegación del propietario | Las 17 entradas recorridas en 5 tamaños mediante pruebas de widgets, con respuestas API controladas |
| Otros roles | Visibilidad del menú comercial, técnico, cliente y lector; permisos efectivos cubiertos además por reglas y llamadas reales en emuladores |
| Diálogos | Abrir/cerrar permisos, cambio de estado y detalles en 5 tamaños; calendario con una fecha escrita fuera del rango del selector |
| Teclado | 12 formularios en vertical y horizontal con espacio de teclado simulado |
| Navegador real | 75 visitas (15 pantallas comerciales × 5 tamaños) en Chrome contra la web y backend publicados en Firebase QA; se espera contenido cargado antes de avanzar. Cero errores o advertencias de consola durante la navegación normal |
| Interrupción de red | Petición abortada deliberadamente en Chrome: mensaje de error visible y reintento que recupera datos reales. El único error de consola de esta fase es el `ERR_INTERNET_DISCONNECTED` inyectado, registrado por separado |
| Revisión visual | Capturas de resumen, solicitudes, empresas y contratos por tamaño; inspección de capturas móviles y de escritorio |

La matriz de widgets utiliza un transporte de API sustituible exclusivamente para las pruebas: comprueba presentación, interacción y manejo de respuestas, sin sustituir las verificaciones del backend. El recorrido Chrome utiliza una cuenta comercial temporal y datos sintéticos que se eliminan al finalizar; conserva auditoría y no reutiliza consecutivos.

## Concurrencia y errores comprobados

- 12 solicitudes simultáneas: identificadores y radicados únicos, consecutivos completos y evento inicial por solicitud.
- 8 comentarios simultáneos: preservación de mensajes y suma correcta de los minutos.
- Dos editores del mismo registro: un guardado aprobado y un conflicto explícito; no sobrescritura silenciosa de la versión enviada.
- Cambio de estado duplicado: una transición y un evento público adicional.
- Renovación duplicada: un historial y vigencia pública consistente.
- Tres ejecuciones simultáneas de avisos: una notificación por vencimiento.
- Consumo simultáneo de una invitación: una aceptación; preservación del rol existente.
- Solicitudes malformadas: nombre vacío, fecha inexistente, importe negativo, paginación excesiva, ruta inválida y acción desconocida.
- Cambio rápido de empresa: una respuesta o un error antiguos no reemplazan el contexto más reciente.
- Fallo de carga y reintento; guardado bloqueado mientras hay petición en curso y formulario conservado ante fallo.
- Acceso vacío y fechas inexistentes; fechas bisiestas y recuperación del selector de calendario.
- Se mantienen las pruebas anteriores de aislamiento, audiencias privadas/técnicas, revocación, adjuntos, importación, cobertura y flujo completo de PQRS.

Estas pruebas son de concurrencia acotada y regresión. No miden capacidad máxima, percentiles de latencia, saturación o comportamiento durante horas de carga.

## Defectos corregidos

1. Callbacks de `setState` devolvían un Future: producían errores en modo de desarrollo.
2. Respuestas de empresas/proyectos podían llegar fuera de orden y mostrar contexto obsoleto. También se protegen los formularios de solicitudes, recursos e invitaciones.
3. Acciones de formulario y paginación desbordaban en pantallas pequeñas o con texto ampliado; ahora pueden ocupar varias líneas.
4. Estados de solicitud y nombres largos estrechaban demasiado el texto. Se reorganizaron las filas y se limitó la longitud visible con acceso al detalle completo.
5. La presentación lateral del acceso no cabía en determinadas alturas. Se muestra cuando dispone del espacio necesario; marca, leyenda y separador admiten texto ampliado.
6. Encabezados e indicadores del dashboard no se adaptaban a texto al 200%.
7. Selectores y diálogos de permisos, estados y detalles necesitaban expansión horizontal o desplazamiento vertical.
8. Se añadieron guardas para impedir envíos repetidos mientras una operación está pendiente.
9. El formulario aceptaba fechas normalizadas por Dart como 30 de febrero; ahora valida el día real. El calendario recupera fechas escritas fuera de su intervalo. Se rechazan importes no finitos.
10. Las fallas de transporte podían mostrar mensajes técnicos como `internal [0]`; ahora se traducen a mensajes comprensibles en español.

## Advertencias y límites pendientes

- `npm audit --omit=dev`: **2 avisos moderados transitivos** (`gaxios` y `uuid`), 0 altos y 0 críticos al ejecutar. Pendiente actualización compatible de la cadena de dependencias; no se aplicó una sustitución forzada de versión mayor.
- iOS: la compilación sin firma de los ajustes de interfaz (`a8a1839`) aprobó en [macOS/GitHub Actions](https://github.com/JairoAndresOrostegui/sistema-de-gestion-de-clientes-y-pqrs/actions/runs/36250981824). Los cambios posteriores tienen su propia ejecución CI. No se ha validado instalación, firma Apple ni uso en un iPhone físico.
- Android: compilación QA; pendiente prueba física de autenticación Google, archivos, interrupciones y ciclo de vida.
- No se ha ejecutado una matriz de Safari/Firefox, versiones de sistema operativo, lectores de pantalla o zoom de navegador. Texto al 200% se verificó con `TextScaler` de Flutter.
- Faltan carga sostenida, pérdidas de conectividad durante subida de adjuntos, recuperación tras cierre del proceso y auditoría de seguridad independiente. La creación de solicitudes todavía no ofrece una clave de idempotencia para reintentos cuando se pierde la respuesta después de persistir: este escenario necesita implementación y pruebas adicionales.
- La navegación interna está comprobada; historial del navegador, enlaces profundos y restauración completa del estado tras recargar no forman parte de esta validación.
- Los pendientes funcionales del pliego siguen en [PROGRESS](PROGRESS.md).

## Reproducción

```powershell
flutter analyze
flutter test
npm --prefix functions run build
$env:FUNCTIONS_DISCOVERY_TIMEOUT='60'
$env:FUNCTIONS_EMULATOR='true'
$env:GCLOUD_PROJECT='demo-dts-gestion'
firebase emulators:exec --only 'auth,firestore,functions,storage' --project demo-dts-gestion 'npm --prefix functions test'

# Requiere sesión Firebase CLI con acceso administrativo exclusivamente a QA.
# Crea y elimina su propia cuenta/datos temporales; no imprime credenciales.
$env:QA_CRAWL='true'
node scripts/qa-smoke.cjs https://sistema-de-gestion-y-pqrs.web.app
```

Resultados locales excluidos de Git: `full-ui-audit.log`, `concurrency-tests.log`, `browser-navigation.log`, `artifacts/browser-audit.json` y `artifacts/audit-*.png`.

La comprobación final publicada está en `browser-navigation-final.log`. El código final `a2a5119` tiene su [ejecución CI](https://github.com/JairoAndresOrostegui/sistema-de-gestion-de-clientes-y-pqrs/actions/runs/36251606023); consultar su estado directamente. Web y APK QA recompilados, Hosting desplegado y datos/cuenta temporal eliminados al cerrar esta auditoría.
