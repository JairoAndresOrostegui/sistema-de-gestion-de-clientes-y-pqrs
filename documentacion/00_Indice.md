# DTS · Documentación del proyecto

Desarrollo & Tecnología Santander. Entorno de entrega: QA. Actualización: 26 de septiembre de 2026.

- [01 · Documento técnico](01_Tecnico.md): arquitectura, datos, módulos, API, permisos, dispositivos, notificaciones, operación y despliegue.
- [02 · Descripción funcional para el cliente](02_Funcional_cliente.md): alcance y funcionamiento del producto.
- [03 · Manual del propietario](03_Manual_propietario.md).
- [04 · Manual del administrador comercial y operativo](04_Manual_comercial.md).
- [05 · Manual del técnico](05_Manual_tecnico.md).
- [06 · Manual del cliente](06_Manual_cliente.md).
- [07 · Manual del lector](07_Manual_lector.md).
- [08 · Validación y entrega](08_Validacion.md): evidencia, límites y configuración pendiente.

Acceso QA: https://sistema-de-gestion-y-pqrs.web.app

Los documentos 01 a 08 también están disponibles en PDF, con texto seleccionable y páginas numeradas, listos para compartir. Los archivos Markdown son las versiones editables. Para el cliente, entregar la descripción funcional y el manual del rol que le corresponda.

Acceso directo a los PDF: [Técnico](01_Tecnico.pdf), [Funcional](02_Funcional_cliente.pdf), [Propietario](03_Manual_propietario.pdf), [Comercial](04_Manual_comercial.pdf), [Técnico adicional](05_Manual_tecnico.pdf), [Cliente](06_Manual_cliente.pdf), [Lector](07_Manual_lector.pdf) y [Validación](08_Validacion.pdf).

La fuente versionada es `front/documentacion`. `node scripts/sync-documentation.cjs` copia estos documentos a la carpeta `documentacion` junto a `front` y `docs`, donde se conserva el prompt original. La copia no elimina archivos adicionales. Los manuales describen el comportamiento implementado; las diferencias frente al alcance futuro están indicadas expresamente.
