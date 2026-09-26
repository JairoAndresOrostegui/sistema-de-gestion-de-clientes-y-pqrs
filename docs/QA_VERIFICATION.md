# Verificación de QA — 26 de septiembre de 2026

Entorno `sistema-de-gestion-y-pqrs`, web y backend publicados mediante Firebase CLI.

- Propietario aprovisionado explícitamente: `jairoandresorostegui@gmail.com`.
- Google y correo/contraseña habilitados.
- Firestore, reglas, Storage, CORS, funciones y tarea de renovaciones desplegados.
- 270 índices compuestos en estado READY al verificar.
- Inicio de sesión real en Chrome con usuario comercial temporal: aprobado.
- Alta mínima de empresa/proyecto y radicación real: aprobadas.
- Listas de empresas, proyectos, tickets, catálogo, eventos y servicios: aprobadas.
- Búsqueda por prefijo y agregaciones de dashboard en Firebase real: aprobadas.
- Dashboard renderizado con la solicitud real de prueba: aprobado.
- Login en escritorio 1440 px y móvil 390 px: aprobado sin errores JavaScript.
- Datos y cuenta temporal eliminados al finalizar; se conserva auditoría de operaciones y los consecutivos no se reutilizan.
- 37 pruebas backend y de aislamiento con emuladores: aprobadas.
- 5 pruebas Flutter y análisis estático: aprobados.
- Web release y APK Android QA compilados, tanto universal como separados por arquitectura (ARM64, ARMv7 y x86_64).

Capturas locales: `artifacts/login-desktop.png`, `artifacts/login-mobile.png`, `artifacts/dashboard-qa.png`. Se excluyen de Git junto con logs y artefactos de compilación.

El [workflow GitHub](https://github.com/JairoAndresOrostegui/sistema-de-gestion-de-clientes-y-pqrs/actions/runs/36248668931) incluye una compilación iOS sin firma en macOS. Su estado se consulta en Actions; una compilación sin firma no es un IPA instalable ni una publicación en TestFlight.

La entrega web final excluye el SDK cliente de Firestore, que no se utiliza: las operaciones de datos pasan por Cloud Functions. Se recompiló web y Android y se repitió la verificación contra QA, incluido acceso autenticado, altas, consultas y dashboard. Las reglas Firestore y el backend permanecen activos.

El documento [PROGRESS](PROGRESS.md) enumera las partes pendientes del alcance ampliado. Los resultados anteriores no equivalen a certificación de producción ni al cierre de todas las fases solicitadas.
