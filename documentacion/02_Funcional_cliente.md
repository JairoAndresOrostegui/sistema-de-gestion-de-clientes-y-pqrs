# DTS · Descripción funcional para el cliente

Desarrollo & Tecnología Santander centraliza la relación entre DTS y sus empresas clientes: proyectos, servicios, cobertura, implementación, conocimiento y atención de solicitudes y PQRS. La plataforma funciona en web y comparte aplicación Flutter para Android e iOS. Esta entrega corresponde al entorno de pruebas QA.

## Acceso y espacio de trabajo

Cada persona utiliza su propia cuenta Google o correo y contraseña. Una cuenta registrada necesita autorización de DTS. Los permisos determinan las empresas, proyectos y opciones visibles. El selector superior establece el contexto de trabajo. En pantalla pequeña el menú se abre con el botón de navegación. Los formularios muestran campos obligatorios, carga y errores; búsquedas y filtros permiten localizar registros.

La fecha se presenta con contexto de Bogotá y los valores usan COP de forma predeterminada. Cada empresa puede tener varios proyectos e instalaciones. No se debe compartir una cuenta entre varias personas: la trazabilidad identifica al usuario que realiza la operación.

## Módulos del producto

| Módulo | Para qué sirve | Acceso habitual |
| --- | --- | --- |
| Resumen | Consultar solicitudes abiertas/nuevas/resueltas y proyectos activos del contexto. | Todos, según permisos. |
| Solicitudes y PQRS | Radicar consultas, soporte, incidentes, peticiones, quejas, reclamos, sugerencias, mejoras o capacitación; seguir respuestas y estado. | DTS, cliente; lector consulta. |
| Empresas | Mantener identidad y contacto de las empresas atendidas. | Propietario y comercial. |
| Proyectos | Organizar alcance, responsables, estado y versión de cada proyecto contratado. | DTS y empresas autorizadas. |
| Instalaciones y versiones | Consultar versiones instaladas, ambiente y despliegue publicado. | Según publicación y permisos. |
| Productos y soluciones | Administrar las soluciones reutilizables ofrecidas por DTS. | Propietario y comercial. |
| Personas y estructura | Relacionar contactos, cargos, áreas y canales de atención. | Propietario y comercial. |
| Catálogo funcional | Explicar módulos, funcionalidades, versiones y preguntas frecuentes. | Cliente ve lo publicado. |
| Contratos y cobertura | Consultar vigencias y soporte; DTS administra los datos internos. | Cliente ve la ficha publicada, sin valores internos. |
| Servicios y renovaciones | Controlar hosting, dominio, licencias y otros servicios con vencimiento. | DTS administra; cliente consulta lo publicado. |
| Implementación y agenda | Registrar reuniones, tareas, hitos, capacitaciones, visitas y compromisos. | Cliente ve eventos publicados. |
| Base de conocimientos | Publicar instrucciones y respuestas reutilizables. | Según publicación. |
| Valores y movimientos | Registrar ingresos, gastos y participaciones. | Propietario y comercial. |
| Enlazar proyecto | Proponer documentación funcional desde archivos o repositorio, revisarla y publicarla. | Propietario y técnico autorizado. |
| Usuarios y permisos | Invitar, asignar y revocar accesos. | Propietario. |
| Notificaciones | Consultar novedades, vencimientos, envío por canal y lectura. | Cada usuario ve su bandeja. |
| Mi cuenta | Consultar identidad, vincular Google, administrar push y ver último navegador/celular. | Cada usuario. |

## Atención de una solicitud

1. Seleccionar empresa y proyecto.
2. Abrir Solicitudes y PQRS y elegir Nueva solicitud.
3. Indicar asunto, descripción, categoría e impacto. Agregar pasos para reproducir, resultado esperado, resultado actual, versión y contacto si se conocen.
4. Guardar y conservar el número DTS asignado. Las evidencias se agregan desde el detalle.
5. DTS clasifica y atiende. Puede pedir información al cliente, resolver en primer nivel o escalar a diagnóstico técnico.
6. Consultar el historial y responder las preguntas usando comentarios públicos. Los adjuntos quedan vinculados a la solicitud.
7. Al recibir la solución, verificar el resultado. El solicitante confirma el cierre o reabre si el problema persiste dentro del plazo permitido.

El sistema conserva el historial al resolver, cerrar o cancelar. Una solicitud fuera de cobertura también puede registrarse; DTS revisa las condiciones de atención. Las notas internas y técnicas tienen visibilidad restringida y no se entregan como comentarios públicos al cliente.

## Avisos y dispositivos

Cada cuenta conserva dos destinos distintos: último navegador web y última aplicación celular. Abrir la web desde un teléfono cuenta como web. Entrar en otro navegador reemplaza el destino web; entrar en otro Android/iPhone reemplaza el celular. Ambos pueden recibir el mismo aviso. Los dispositivos anteriores pueden seguir teniendo una sesión abierta, pero dejan de ser el destino elegido para avisos nuevos de su tipo.

En Mi cuenta, pulsar Activar notificaciones en este dispositivo y aceptar el permiso. Si se rechaza o el navegador no admite push, la bandeja sigue disponible. En iOS, el envío depende además de la configuración Apple/APNs de DTS. Cerrar sesión desactiva el destino correspondiente; volver a entrar lo registra otra vez.

Crear una solicitud, agregar una respuesta/evidencia o cambiar de estado genera un registro de notificación. Se notifica solo a los destinatarios autorizados, incluidos administradores y clientes según el contenido. Los avisos en pantalla bloqueada son generales; abrirlos lleva al detalle protegido por inicio de sesión.

En Notificaciones se puede desplegar cada aviso para ver el envío a web y celular, abrir el detalle o marcarlo Leído. La campana del detalle de una solicitud muestra la trazabilidad. “Aceptado por Firebase” indica envío aceptado por el proveedor; “recibido”, “abierto” y “leído” requieren confirmación posterior. La ausencia de confirmación no significa que el destinatario haya ignorado el aviso.

## Alcance de la entrega

Esta versión cubre el portal y la gestión operativa descrita. No reemplaza un sistema contable, no publica código privado a clientes y no guarda claves de infraestructura en texto plano. El correo externo de avisos, la distribución por tiendas y ciertas integraciones privadas dependen de configuración adicional. La evidencia de pruebas y requisitos pendientes se detalla en el documento de validación de esta entrega.

Para ayuda, conservar el número DTS de la solicitud y describir el problema, la hora aproximada, el dispositivo y los pasos. No enviar contraseñas ni claves en comentarios o capturas.
