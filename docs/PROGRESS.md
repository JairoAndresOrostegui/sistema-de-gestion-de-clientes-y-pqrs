# Estado de entrega — QA

Fecha: 26 de septiembre de 2026. Plataforma Flutter web, Android e iOS. Este documento distingue lo operativo de lo pendiente; no declara el alcance completo listo para producción.

## Operativo con persistencia Firebase

- Autenticación Google y correo/contraseña, recuperación, verificación y vínculo explícito de proveedores.
- Bootstrap administrativo del propietario `jairoandresorostegui@gmail.com` en QA. Sin escalamiento de permisos desde el registro público.
- Roles, membresías por empresa/proyecto, invitaciones consumibles, revocación, perfiles y auditoría.
- Empresas mínimas, proyectos independientes, contactos y estructura flexible, productos, instalaciones/versiones.
- Radicación de PQRS y soporte, filtros, búsqueda por prefijo, paginación, conversación por audiencia, adjuntos privados, estados justificados y escalamiento al propietario.
- Catálogo manual y artículos con publicación explícita; contexto de funcionalidades y guías al radicar.
- Contratos, cobertura fuera/dentro de vigencia, SLA en horario hábil y pausas; servicios, renovación histórica, avisos internos sin duplicados.
- Agenda, hitos, visitas, capacitaciones y despliegues; importes pactados, ingresos, gastos y participaciones.
- Dashboard con agregaciones por ámbito y CSV de páginas autorizadas.
- Importación local acotada, GitHub público, previsualización editable y aprobación; evidencia reservada; reimportación sin sobrescribir textos manuales.

## Pendientes precisos para completar el pliego

1. **Documentos de empresa/contrato:** los adjuntos están implementados en solicitudes; falta gestor independiente de propuestas, actas y archivos contractuales con versión y firma.
2. **SLA avanzado:** selección de políticas por categoría/prioridad, alertas de riesgo/incumplimiento, bolsa de horas con saldo y autorización de atenciones extraordinarias. Hoy hay snapshot de política por contrato/proyecto y registro de minutos por ticket.
3. **Catálogo y sincronización:** falta interfaz final de revisión de `catalogReviews`, visor de versiones históricas, sincronización programada/webhook y estado de revocación. La sincronización actual es manual; las actualizaciones propuestas no reemplazan publicaciones existentes.
4. **GitHub privado:** adaptador de GitHub App implementado, pero faltan App ID, instalación autorizada y clave privada inyectada por Secret Manager en el runtime; no está activado en QA.
5. **Informes avanzados:** series por rango, distribución por responsable/funcionalidad, vencimientos ordenados, carga de agentes y PDF. Dashboard inicial muestra conteos reales y listas paginadas; no representa todas las métricas del pliego.
6. **Administración:** búsqueda remota en selectores de más de 100 empresas/proyectos; editor visual de membresías existentes y visor de auditoría/historial. Para más de 30 proyectos específicos usar membresía de empresa o ampliar el modelo.
7. **Correo y push:** centro de notificaciones persistente operativo; correos salientes y push pendientes de proveedor. No se envía correo ni se afirma que fue enviado.
8. **Privacidad y operación productiva:** retención automatizada, política de backups con prueba de restauración, monitoreo, App Check, cuarentena/antivirus de adjuntos y revisión de seguridad independiente.
9. **Distribución móvil:** APK Android QA compilado; firma de distribución propia pendiente. iOS preparado en código, configuración Firebase y callback Google; compilación sin firma en ejecución remota en macOS mediante GitHub Actions. Firma Apple, prueba en dispositivo y publicación en App Store/TestFlight pendientes.
Las invitaciones del propietario también admiten cuentas nuevas comerciales, técnicas y lectoras; nunca permiten reclamar el rol propietario. Las cuentas existentes conservan su rol hasta que el propietario lo modifique explícitamente.

Siguiente incremento recomendado: gestor documental y editor de revisiones de catálogo, seguido por políticas SLA avanzadas y reportes.

## Verificación ejecutada

- `flutter analyze`: sin incidencias.
- `flutter test`: 5 pruebas aprobadas (alta mínima, CSV seguro, Bogotá y vistas móvil/escritorio).
- TypeScript: compilación aprobada.
- Emuladores Auth/Firestore/Functions/Storage: 37 pruebas aprobadas, incluidos permisos API, reglas, adjuntos, flujo completo, invitaciones de equipo, importación y recordatorios.
- Web release: compilada.
- Android debug QA: APK compilado.
- QA desplegado: autenticación, altas mínimas, consultas, búsqueda e indicadores verificados contra Firebase real con una cuenta comercial temporal; datos y cuenta eliminados al finalizar. La auditoría conserva el registro de verificación.
- iOS: comprobación remota sin firma en curso; consultar [GitHub Actions](https://github.com/JairoAndresOrostegui/sistema-de-gestion-de-clientes-y-pqrs/actions/runs/36248668931). No se afirma todavía que la compilación haya aprobado.

Consultar README para comandos y los resultados finales de despliegue. Los fixtures y pruebas usan datos ficticios en emuladores y no se cargan automáticamente en QA.
