# DTS · Arquitectura y permisos

Flutter 3.41 / Dart 3.11 comparte interfaz y dominio de presentación entre web, Android e iOS. Se conserva la identidad de `front_dts`: azul `#0A3D62` y acento `#FFC300`. El portal funciona de forma independiente; no se modificó el sitio corporativo. Firebase Authentication identifica al usuario. Cloud Functions TypeScript valida permisos y entradas Zod, ejecuta operaciones y escribe auditoría. Firestore y Storage aplican reglas adicionales a solicitudes directas.

## Datos y relaciones

| Colección | Relación y campos mínimos | Visibilidad |
| --- | --- | --- |
| users | UID de Firebase Auth, role, active, permissions | Propietario / usuario propio |
| memberships | UID + empresa, projectIds o allProjects, ticketScope, active | Propietario / usuario propio |
| invitations | Hash de código aleatorio, correo, membresía, caducidad de 7 días, consumo único | Solo servidor |
| companies | Solo name obligatorio | DTS y miembros de la empresa |
| contacts | companyId, name; cargo/área/jerarquía/sede opcionales | DTS comercial / propietario |
| products | name, versión y estado; reutilizable entre empresas | DTS |
| projects | companyId y name; referencia productId, estado, alcance, versión | DTS y miembros autorizados |
| installations | companyId, projectId, name, versión, ambiente y fecha | DTS; clientes si published |
| contracts | Empresa/proyecto, nombre, vigencia, tipo, importes, cobertura, SLA opcional | DTS |
| publicContracts | Proyección explícita de vigencia, nombre, tipo y estado | Miembros autorizados |
| services | Empresa/proyecto, nombre, proveedor, vigencia, costo/precio y referencia de secreto | DTS |
| publicServices | Proyección sin costo, margen, notas ni referencias técnicas | Miembros autorizados |
| contracts o services / renewals | Historial inmutable de vigencias | Servidor; UI de historial pendiente |
| catalog | Empresa/proyecto, nombre, módulo, texto funcional, versión, published | DTS; clientes si published |
| catalog / history | Copia de cada versión anterior editada | Reservado; visor pendiente |
| catalogOrigins | Fuente/commit/confianza, nunca contenido completo de archivos | Técnico autorizado |
| repositories | Fuente y commit, huellas por candidato; varias fuentes por proyecto | Técnico autorizado |
| imports | Vista previa, evidencias por ruta, diferencias y aprobación | Técnico autorizado |
| catalogReviews | Propuesta de actualización sin sobrescribir texto manual | Técnico autorizado; editor final pendiente |
| tickets | Empresa/proyecto, consecutivo, solicitante, estado, categoría, impacto, prioridad, cobertura, snapshot SLA | Según membresía y visibilidad por solicitante |
| tickets / public | Conversación pública y cambios de estado | Usuarios autorizados del ticket |
| tickets / internal | Notas comerciales y operativas | Propietario / comercial |
| tickets / technical | Diagnóstico reservado | Propietario / técnico con permiso y membresía |
| articles | Empresa/proyecto, contenido funcional, versión y published | DTS; clientes si published |
| events | Empresa/proyecto, tarea/hito/visita/capacitación/despliegue, fecha y published | DTS; clientes si published |
| finance | Movimientos y participaciones de empresa/proyecto | DTS; nunca clientes |
| notifications | Audiencia, envío interno, estado, leído por UID | Destinatario o equipo DTS |
| audit | Actor, fecha, entidad, acción y resumen sin secretos | Propietario |
| counters | Consecutivo transaccional | Solo servidor |

Los IDs no representan permisos. Cada operación vuelve a leer el perfil activo y la membresía; una revocación no depende de esperar a la expiración de custom claims. Solo el propietario asigna roles. Un comercial no puede obtener acceso técnico aunque se agregue por error `technical` a su lista de permisos.

## Archivos

`attachments/{ticketId}/{public|internal|technical}/{uid}/{filename}` aplica los mismos permisos del ticket. Subidas inmutables, máximo 10 MB por archivo y 5 por comentario. Solo PNG/JPEG/WebP/PDF/TXT. La aplicación descarga bytes autenticados; no publica URLs de descarga con tokens permanentes. CORS permite los dominios QA. Aún no hay antivirus ni cuarentena de adjuntos: revisar antes de habilitar cargas externas en producción.

## SLA y recordatorios

Las solicitudes siempre se reciben, incluso fuera de cobertura. Se busca contrato de soporte activo vigente para ese proyecto y se fija una copia de la política al radicar. Sin política: `sin SLA configurado`. Las fechas se calculan en `America/Bogota`, con días hábiles, horas y festivos configurados; la espera al cliente pausa objetivos mediante minutos hábiles auditados. La prioridad final pertenece a DTS. Los objetivos no son términos legales universales.

La tarea diaria de renovaciones corre a las 07:00 de Bogotá, consulta en páginas de 100 y usa IDs deterministas por entidad, vencimiento y umbral (30, 7, 1 y vencido). Repetirla no duplica avisos. Una renovación conserva historia y marca obsoletos los avisos anteriores. No se envía correo sin proveedor configurado.

## Consultas

Las pantallas usan paginación por documento (30 por página, máximo 100), filtros aplicados en servidor y búsqueda por prefijo normalizado. Los indicadores usan agregaciones `count`, no descargas completas. Los selectores iniciales cargan hasta 100 empresas/proyectos; para más registros se requiere implementar búsqueda remota en selectores. Los índices se generan con `node scripts/generate-indexes.cjs`.

## Datos personales

No se exige NIT, correo o teléfono para crear una empresa. No se registran contraseñas, contenido fuente completo ni tokens en auditoría. La retención, respaldo y exportación de datos deben configurarse según el negocio. No se afirma cumplimiento normativo automático. QA no debe contener datos sensibles reales durante la validación inicial.
