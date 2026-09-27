# DTS · Pruebas físicas y decisión de salida

Fecha de preparación: 27 de septiembre de 2026. Entorno: **QA**.
Web: https://sistema-de-gestion-y-pqrs.web.app. Android QA:
https://sistema-de-gestion-y-pqrs.web.app/downloads/dts-qa-debug.apk.
APK QA debug: 166.787.135 bytes, SHA-256
`A021411391FD20B6A75B80B7471DB7A49E416BDDD1357C3498943301E408AD09`.

## Preparación

- El propietario entra con su cuenta Google y crea invitaciones separadas para
  propietario, comercial, técnico, cliente y lector. Cada participante usa su
  propia cuenta. No introducir información real de clientes durante el ensayo.
- Registrar modelo, Android y versión, navegador, red, rol, hora y resultado.
  Ejecutar al menos un teléfono Android real y un navegador de escritorio;
  probar Chrome móvil si el equipo lo usa. iPhone requiere firma Apple y
  TestFlight; todavía no hay IPA instalable.
- El APK enlazado es **debug QA**, firmado por este PC. Si existe una instalación
  anterior firmada con otra clave, Android puede rechazar la actualización.
  Desinstalar la anterior y reinstalar; esto elimina sesión y datos locales,
  mientras los datos en Firebase permanecen.
- La clave privada release usada en el PC anterior no está en este equipo.
  Recuperarla de la copia segura antes de crear otra versión release. No crear
  una clave nueva para sustituirla sin decidir cómo actualizar los equipos.

## Casos que deben firmar los encargados

| Rol | Acción | Comprobación |
| --- | --- | --- |
| Propietario | Iniciar con Google, invitar usuario, revocar acceso | Sin invitación no hay privilegios; revocación se aplica al siguiente acceso |
| Comercial | Crear empresa, proyecto, contacto, contrato y servicio | Se conservan tras cerrar y abrir web o app; el contexto seleccionado es correcto |
| Cliente | Radicar PQRS con adjunto, leer y responder | El ticket aparece al equipo autorizado; no ve notas internas ni técnicas |
| Técnico | Clasificar, asignar, escalar, responder con audiencia y resolver | Estado, motivo, historial, adjunto y SLA se mantienen; audiencias aisladas |
| Lector | Consultar los ámbitos autorizados | No puede editar ni acceder a otros clientes/proyectos |
| Propietario / técnico | Registrar destino de notificaciones, enviar prueba controlada | Bandeja, aviso Android en primer/segundo plano y apertura llevan al caso correcto |
| Equipo | Importar proyecto público o carpeta ficticia y revisar catálogo | Las propuestas requieren aprobación; una nueva importación conserva ediciones manuales |

En teléfono repetir inicio con Google, elección de archivos/cámara si corresponde,
subida con cambio de Wi-Fi a datos móviles, app en segundo plano, proceso cerrado,
texto ampliado y reinicio. Probar como mínimo una denegación de permiso y un
reintento de red. No ejecutar el script automatizado
`qa-android-notifications.cjs` en un teléfono real: limpia datos de la app.

## Registro y decisión

Cada caso queda **aprobado**, **falló** o **no probado**, con responsable, fecha,
dispositivo y evidencia. Anotar pasos reproducibles y captura para fallos. El go
de pruebas físicas requiere que autenticación, aislamiento de roles, PQRS,
adjuntos, cambios de estado y persistencia aprueben en equipos reales.

Ese go no cierra los módulos ampliados del pliego enumerados en
`docs/PROGRESS.md`. Antes de limpiar QA o pasar a producción: acordar el alcance
aceptado, recuperar y respaldar la firma release, ensayar restauración de datos,
definir retención/monitoreo/App Check, revisar adjuntos y confirmar proveedor
de correo, GitHub privado y Apple si forman parte de la salida. La decisión debe
quedar firmada por el responsable de negocio y el técnico.
