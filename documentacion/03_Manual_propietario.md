# Manual del propietario y administrador principal

DTS · Desarrollo & Tecnología Santander. Entorno QA. Cuenta principal autorizada: jairoandresorostegui@gmail.com.

## Qué puede hacer

Dispone de todos los módulos: resumen, empresas, proyectos, instalaciones, productos, contactos, catálogo, contratos, servicios, agenda, conocimientos, valores, solicitudes, enlace técnico, accesos, notificaciones y cuenta. Puede gestionar información comercial y técnica, publicar contenido para clientes e invitar o revocar usuarios.

## 1. Entrar y preparar los avisos

1. Abrir https://sistema-de-gestion-y-pqrs.web.app y elegir Continuar con Google con la cuenta principal.
2. Verificar el rol Propietario en la aplicación.
3. Abrir Mi cuenta y comprobar Mis últimos dispositivos.
4. Pulsar Activar notificaciones en este dispositivo y aceptar el permiso. El último navegador y último celular se guardan por separado.
5. Si el permiso está bloqueado, habilitarlo en ajustes del navegador/sistema y volver a activar desde Mi cuenta.

## 2. Crear la estructura de un cliente

1. Abrir Empresas, pulsar Nuevo, escribir el nombre y guardar. Los datos legales y de contacto se completan después.
2. Seleccionar la empresa en el contexto superior.
3. Abrir Proyectos, crear el proyecto y registrar nombre, alcance, producto, estado y responsables conocidos.
4. Seleccionar ese proyecto para continuar trabajando sin mezclar información.
5. En Personas y estructura, crear contactos y completar cargo, área, dependencia, sede y canal preferido.
6. En Productos y soluciones, mantener la ficha de la solución ofrecida. En Instalaciones y versiones, registrar cada versión instalada, ambiente, URL y fecha.

Para corregir una ficha, buscarla en su módulo, abrir Editar, ajustar campos y guardar. Si se informa que otro usuario la modificó, recargar y revisar antes de aplicar de nuevo el cambio. Usar filtros y paginación para revisar conjuntos grandes.

## 3. Contratos, cobertura y servicios

1. Abrir Contratos y cobertura en la empresa/proyecto seleccionado.
2. Crear el contrato con tipo, vigencia y datos conocidos. Para soporte, completar canales, exclusiones, bolsa de horas y política de atención cuando corresponda.
3. Revisar días hábiles, horario, festivos y objetivos de respuesta/resolución de la política SLA.
4. Publicar solamente cuando la ficha pública esté lista para el cliente. Los valores y campos internos permanecen separados.
5. En Servicios y renovaciones, registrar cada dominio, hosting, SSL, licencia u otro servicio con proveedor, referencia y vigencia. Usar referencias al gestor de secretos para claves; no escribirlas en notas.
6. Al renovar, usar Renovar, registrar el nuevo período y guardar. Se conserva el período anterior y se invalidan avisos pendientes de la vigencia antigua.
7. En Valores y movimientos, registrar ingreso, gasto o participación con moneda y fecha. Revisar que pertenezca al proyecto correcto.

## 4. Preparar contenido e implementación

1. En Catálogo funcional, describir módulos, funciones, roles, versión y preguntas frecuentes.
2. En Base de conocimientos, escribir instrucciones reutilizables y publicar las que pueda consultar el cliente.
3. En Implementación y agenda, crear tarea, hito, capacitación, visita, reunión o despliegue; asignar fecha y responsable, asistentes y material cuando corresponda.
4. Actualizar estado al avanzar y publicar únicamente los eventos visibles para el cliente.

## 5. Invitar y controlar usuarios

1. Abrir Usuarios y permisos y crear la invitación para el correo correcto.
2. Elegir rol, empresa y proyectos; usar Todos los proyectos solo cuando corresponda.
3. Elegir si el cliente verá solicitudes del proyecto o solo las radicadas por él.
4. Compartir el enlace de invitación por el canal habitual autorizado. La invitación vence a los siete días y se acepta con ese correo verificado.
5. Revisar Equipo y usuarios y usar Editar permisos para ajustar rol, membresía, permisos técnicos o estado activo.
6. Revocar acceso cuando la persona deje de participar. La autorización se revisa en el servidor y los nuevos envíos se cancelan si ya no corresponden.

No otorgar `manage` a un cliente o lector salvo que se pretenda habilitar gestión adicional. Para un técnico, asignar proyectos y habilitar el permiso técnico. El sistema impide quitarse a sí mismo la administración principal o desactivar la propia cuenta desde esa acción.

## 6. Gestionar solicitudes de principio a fin

1. Abrir Solicitudes y PQRS, filtrar por proyecto, estado, prioridad, responsable o texto.
2. Abrir la solicitud y revisar descripción, evidencia y cobertura.
3. Usar Cambiar estado, seleccionar una transición disponible y justificarla. Clasificar y pasar a primer nivel; escalar cuando necesite diagnóstico.
4. Agregar respuesta pública para informar al cliente. Usar Nota interna para coordinación comercial y Nota técnica para diagnóstico reservado.
5. Agregar evidencia en la audiencia correcta y registrar minutos de trabajo. No adjuntar material técnico reservado como público.
6. Si falta información, pasar a Esperando cliente. Al recibirla, retomar el estado permitido.
7. Diagnosticar, ejecutar la solución y marcar Resuelto con una explicación verificable. El solicitante puede confirmar Cerrado o reabrir conforme al plazo.
8. Abrir la campana Trazabilidad de notificaciones: revisar cada evento, origen, destinatarios, envío web/celular e indicadores de lectura.

## 7. Enlazar documentación técnica

1. Abrir Enlazar proyecto en el contexto correcto.
2. Importar el archivo de inspección local o usar el repositorio configurado. La integración privada requiere la GitHub App preparada por DTS.
3. Revisar las propuestas de módulos y funcionalidades; corregir descripciones y descartar lo que no deba publicarse.
4. Aprobar solamente los elementos elegidos. Revisar el resultado en Catálogo funcional y su publicación al cliente.

La importación propone contenido, no lo publica automáticamente. No cargar secretos ni archivos de credenciales.

## 8. Notificaciones y salida

Abrir Notificaciones, desplegar el aviso, revisar los dos canales y elegir Ver detalle o Leído. El historial de cada administrador es individual. “Aceptado por Firebase” no es una prueba de recepción; apertura y lectura aparecen al confirmarse. Sin permiso push, el aviso sigue en la bandeja. Cerrar sesión al terminar, especialmente en equipos compartidos.

Si un envío falla, revisar la trazabilidad y el registro de dispositivos; activar permisos o iniciar sesión en el equipo correcto. Para fallos persistentes del proveedor, usar el procedimiento del documento técnico. Nunca marcar una entrega como recibida sin evidencia del cliente.
