import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class FieldDef {
  const FieldDef(
    this.key,
    this.title, {
    this.required = false,
    this.options,
    this.kind = 'text',
    this.initial,
    this.lines = 1,
  });
  final String key, title, kind;
  final bool required;
  final List<String>? options;
  final dynamic initial;
  final int lines;
}

const _name = FieldDef('name', 'Nombre', required: true);
const _description = FieldDef('description', 'Descripción', lines: 3);
const _start = FieldDef(
  'startDate',
  'Fecha de inicio',
  kind: 'date',
  required: true,
);
const _end = FieldDef(
  'endDate',
  'Fecha de vencimiento',
  kind: 'date',
  required: true,
);
const _published = FieldDef(
  'published',
  'Publicar para el cliente',
  kind: 'bool',
  initial: false,
);
const _currency = FieldDef(
  'currency',
  'Moneda',
  options: ['COP', 'USD', 'EUR'],
  initial: 'COP',
);
const resourceFields = <String, List<FieldDef>>{
  'products': [
    _name,
    _description,
    FieldDef('version', 'Versión'),
    FieldDef(
      'status',
      'Estado',
      options: ['activo', 'mantenimiento', 'retirado'],
      initial: 'activo',
    ),
  ],
  'installations': [
    _name,
    FieldDef('version', 'Versión instalada', required: true),
    FieldDef(
      'environment',
      'Ambiente',
      options: ['desarrollo', 'qa', 'produccion'],
      initial: 'qa',
    ),
    FieldDef('branch', 'Sede / Instalación'),
    FieldDef('url', 'URL de acceso'),
    FieldDef('deployedAt', 'Fecha de despliegue', kind: 'date', required: true),
    _description,
    _published,
  ],
  'companies': [
    _name,
    FieldDef('legalName', 'Razón social'),
    FieldDef('nit', 'NIT'),
    FieldDef('sector', 'Sector'),
    _description,
    FieldDef('address', 'Dirección / Sede principal'),
    FieldDef('email', 'Correo', kind: 'email'),
    FieldDef('phone', 'Teléfono'),
    FieldDef('website', 'Sitio web'),
    FieldDef('hours', 'Horario de atención'),
    FieldDef('timezone', 'Zona horaria', initial: 'America/Bogota'),
    FieldDef(
      'status',
      'Relación',
      options: ['prospecto', 'activo', 'inactivo'],
      initial: 'activo',
    ),
  ],
  'projects': [
    _name,
    _description,
    FieldDef('type', 'Tipo de solución', initial: 'Software'),
    FieldDef('productId', 'Referencia de producto'),
    FieldDef('objective', 'Objetivo', lines: 2),
    FieldDef('scope', 'Alcance acordado', lines: 3),
    FieldDef(
      'status',
      'Ciclo de vida',
      options: [
        'negociacion',
        'contratado',
        'desarrollo',
        'implementacion',
        'activo',
        'mantenimiento',
        'suspendido',
        'finalizado',
      ],
      initial: 'negociacion',
    ),
    FieldDef('version', 'Versión instalada'),
    FieldDef('environment', 'Ambiente', initial: 'QA'),
    FieldDef('technicalOwner', 'Responsable técnico'),
    FieldDef('commercialOwner', 'Responsable comercial'),
    FieldDef('startDate', 'Inicio estimado', kind: 'date'),
    FieldDef('endDate', 'Final estimado', kind: 'date'),
  ],
  'contacts': [
    _name,
    FieldDef('position', 'Cargo'),
    FieldDef('area', 'Área / Dependencia'),
    FieldDef('parentArea', 'Área superior (opcional)'),
    FieldDef('branch', 'Sede'),
    FieldDef('email', 'Correo', kind: 'email'),
    FieldDef('phone', 'Teléfono'),
    FieldDef('availability', 'Disponibilidad'),
    FieldDef('responsibilities', 'Responsabilidades', lines: 2),
    FieldDef('preferredContact', 'Canal preferido'),
    FieldDef('primary', 'Contacto principal', kind: 'bool'),
  ],
  'catalog': [
    _name,
    FieldDef('module', 'Módulo', initial: 'General'),
    _description,
    FieldDef('faq', 'Documentación / Preguntas frecuentes', lines: 4),
    FieldDef('roles', 'Roles afectados'),
    FieldDef('version', 'Versión'),
    FieldDef(
      'status',
      'Estado',
      options: ['disponible', 'planificado', 'retirado'],
      initial: 'disponible',
    ),
    _published,
  ],
  'articles': [_name, _description, FieldDef('version', 'Versión'), _published],
  'events': [
    _name,
    FieldDef(
      'type',
      'Tipo',
      options: [
        'tarea',
        'hito',
        'capacitacion',
        'visita',
        'reunion',
        'despliegue',
        'compromiso',
      ],
      initial: 'tarea',
    ),
    _description,
    FieldDef('dueDate', 'Fecha objetivo', kind: 'date', required: true),
    FieldDef('owner', 'Responsable'),
    FieldDef('attendees', 'Asistentes'),
    FieldDef('materials', 'Materiales / Acta / Enlaces', lines: 3),
    FieldDef('version', 'Versión'),
    FieldDef(
      'status',
      'Estado',
      options: ['pendiente', 'en_curso', 'completado', 'cancelado'],
      initial: 'pendiente',
    ),
    _published,
  ],
  'contracts': [
    _name,
    FieldDef(
      'type',
      'Tipo de contrato',
      options: [
        'venta',
        'implementacion',
        'soporte',
        'mantenimiento',
        'hosting',
        'dominio',
        'otro',
      ],
      initial: 'soporte',
    ),
    _description,
    _start,
    _end,
    FieldDef('amount', 'Valor pactado', kind: 'number', initial: 0),
    _currency,
    FieldDef('periodicity', 'Periodicidad', initial: 'anual'),
    FieldDef('paymentTerms', 'Condiciones de pago'),
    FieldDef('signatories', 'Firmantes'),
    FieldDef('signatureDate', 'Fecha de firma', kind: 'date'),
    FieldDef('version', 'Versión', initial: '1'),
    FieldDef('channels', 'Canales de soporte', initial: 'Portal'),
    FieldDef('exclusions', 'Exclusiones de cobertura', lines: 3),
    FieldDef('hoursIncluded', 'Bolsa de horas', kind: 'number', initial: 0),
    FieldDef(
      'status',
      'Estado',
      options: ['borrador', 'activo', 'vencido', 'renovado', 'cancelado'],
      initial: 'activo',
    ),
    _published,
  ],
  'services': [
    _name,
    FieldDef(
      'type',
      'Tipo de servicio',
      options: [
        'dominio',
        'dns',
        'hosting',
        'vps',
        'base_datos',
        'correo',
        'ssl',
        'licencia',
        'api',
        'soporte',
        'otro',
      ],
      initial: 'hosting',
    ),
    FieldDef('provider', 'Proveedor'),
    FieldDef('reference', 'Identificador / Referencia'),
    FieldDef('owner', 'Responsable de renovación'),
    FieldDef('ownership', 'Titular', initial: 'Cliente'),
    FieldDef('cost', 'Costo', kind: 'number', initial: 0),
    FieldDef('price', 'Precio cobrado', kind: 'number', initial: 0),
    _currency,
    FieldDef('periodicity', 'Periodicidad', initial: 'anual'),
    _start,
    _end,
    FieldDef(
      'status',
      'Estado',
      options: ['activo', 'vencido', 'renovado', 'cancelado'],
      initial: 'activo',
    ),
    FieldDef(
      'paymentReference',
      'Referencia del método de pago (sin datos sensibles)',
    ),
    FieldDef(
      'secretReference',
      'Referencia a gestor de secretos (nunca la clave)',
    ),
    FieldDef('url', 'Enlace de administración'),
    FieldDef('notes', 'Notas operativas', lines: 3),
    _published,
  ],
  'finance': [
    _name,
    FieldDef(
      'type',
      'Movimiento',
      options: ['ingreso', 'gasto', 'participacion'],
      initial: 'ingreso',
    ),
    FieldDef('amount', 'Valor', kind: 'number', required: true),
    _currency,
    FieldDef('date', 'Fecha', kind: 'date', required: true),
    _description,
  ],
};
const resourceTitles = <String, String>{
  'products': 'Productos y soluciones',
  'installations': 'Instalaciones y versiones',
  'companies': 'Empresas',
  'projects': 'Proyectos',
  'contacts': 'Personas y estructura',
  'catalog': 'Catálogo funcional',
  'articles': 'Base de conocimientos',
  'events': 'Implementación y agenda',
  'contracts': 'Contratos y cobertura',
  'services': 'Servicios y renovaciones',
  'finance': 'Valores y movimientos',
  'publicContracts': 'Mis contratos',
  'publicServices': 'Mis servicios',
};
const resourceDescriptions = <String, String>{
  'products': 'Soluciones que pueden acompañar a varias empresas.',
  'installations': 'Versiones y ambientes de cada proyecto.',
  'companies': 'Relaciones que crecen con cada proyecto.',
  'projects': 'Del primer acuerdo a la mejora continua.',
  'contacts': 'Las personas, áreas y sedes de cada empresa.',
  'catalog': 'Lo que tu solución hace, explicado con claridad.',
  'articles': 'Respuestas útiles, siempre a mano.',
  'events': 'Entregas, capacitaciones y próximos pasos.',
  'contracts': 'Acuerdos, vigencias y condiciones de soporte.',
  'services': 'Anticípate a cada vencimiento.',
  'finance': 'Valores pactados, ingresos y gastos por proyecto.',
  'publicContracts': 'Acuerdos publicados por DTS.',
  'publicServices': 'Servicios publicados por DTS.',
};

Future<bool> editResource(
  BuildContext context,
  Session session,
  String collection, {
  Json? record,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ResourceForm(
        session: session,
        collection: collection,
        record: record,
      ),
    ) ??
    false;

class ResourceForm extends StatefulWidget {
  const ResourceForm({
    super.key,
    required this.session,
    required this.collection,
    this.record,
  });
  final Session session;
  final String collection;
  final Json? record;
  @override
  State<ResourceForm> createState() => _ResourceFormState();
}

class _ResourceFormState extends State<ResourceForm> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final values = <String, dynamic>{};
  String? company, project, error;
  bool busy = false, slaEnabled = false;
  final response = TextEditingController(text: '240'),
      resolution = TextEditingController(text: '1440'),
      holidays = TextEditingController();
  final startHour = TextEditingController(text: '8'),
      endHour = TextEditingController(text: '17');
  Set<int> weekdays = {1, 2, 3, 4, 5};
  List<Json> projects = [];
  @override
  void initState() {
    super.initState();
    company = widget.record?['companyId'] ?? widget.session.companyId;
    project = widget.record?['projectId'] ?? widget.session.projectId;
    projects = widget.session.projects;
    for (final f in resourceFields[widget.collection]!) {
      final value = widget.record?[f.key] ?? f.initial;
      if (f.kind == 'bool' || f.options != null) {
        values[f.key] = value ?? (f.kind == 'bool' ? false : null);
      } else {
        controllers[f.key] = TextEditingController(
          text: value?.toString() ?? '',
        );
      }
    }
    final sla = widget.record?['sla'];
    if (sla != null) {
      slaEnabled = true;
      response.text = '${sla['responseMinutes']}';
      resolution.text = '${sla['resolutionMinutes']}';
      startHour.text = '${sla['startHour']}';
      endHour.text = '${sla['endHour']}';
      holidays.text = (sla['holidays'] as List? ?? []).join(', ');
      weekdays = (sla['weekdays'] as List).cast<int>().toSet();
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    response.dispose();
    resolution.dispose();
    holidays.dispose();
    startHour.dispose();
    endHour.dispose();
    super.dispose();
  }

  Future<void> chooseCompany(String? value) async {
    setState(() {
      company = value;
      project = null;
      projects = [];
    });
    if (value != null) {
      try {
        final result = await Api.list('projects', {
          'companyId': value,
          'limit': 100,
        });
        if (mounted && company == value) {
          setState(() => projects = jsonList(result['items']));
        }
      } catch (e) {
        if (mounted && company == value) {
          setState(() => error = readableError(e));
        }
      }
    }
  }

  Future<void> save() async {
    if (busy) return;
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = <String, dynamic>{
        ...values,
        if (!['companies', 'products'].contains(widget.collection))
          'companyId': company,
        if (![
          'companies',
          'products',
          'projects',
          'contacts',
        ].contains(widget.collection))
          'projectId': project,
      };
      if (widget.collection == 'contacts' && project != null) {
        data['projectId'] = project;
      }
      for (final f in resourceFields[widget.collection]!) {
        if (controllers.containsKey(f.key)) {
          final v = controllers[f.key]!.text.trim();
          if (f.kind == 'date' && v.isEmpty) continue;
          data[f.key] = f.kind == 'number' ? num.tryParse(v) ?? 0 : v;
        }
      }
      if (widget.collection == 'contracts' && slaEnabled) {
        data['sla'] = {
          'timezone': 'America/Bogota',
          'weekdays': weekdays.toList()..sort(),
          'startHour': int.parse(startHour.text),
          'endHour': int.parse(endHour.text),
          'holidays': holidays.text
              .split(',')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList(),
          'responseMinutes': int.parse(response.text),
          'resolutionMinutes': int.parse(resolution.text),
        };
      }
      await Api.call('save', {
        'collection': widget.collection,
        'data': data,
        if (widget.record != null) 'id': widget.record!['id'],
        if (widget.record?['updatedAt'] != null)
          'updatedAt': widget.record!['updatedAt'],
      });
      if (['companies', 'projects'].contains(widget.collection)) {
        await widget.session.load();
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(FieldDef f) {
    if (f.kind == 'bool') {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(f.title),
        subtitle: f.key == 'published'
            ? const Text(
                'Solo información aprobada y adecuada para el cliente.',
              )
            : null,
        value: values[f.key] == true,
        onChanged: busy ? null : (v) => setState(() => values[f.key] = v),
      );
    }
    if (f.options != null) {
      return DropdownButtonFormField<String>(
        initialValue: values[f.key],
        isExpanded: true,
        decoration: InputDecoration(labelText: f.title),
        items: f.options!
            .map((v) => DropdownMenuItem(value: v, child: Text(label(v))))
            .toList(),
        onChanged: (v) => values[f.key] = v,
      );
    }
    return TextFormField(
      controller: controllers[f.key],
      maxLines: f.lines,
      keyboardType: f.kind == 'number'
          ? TextInputType.number
          : f.kind == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: '${f.title}${f.required ? ' *' : ''}',
        hintText: f.kind == 'date' ? 'AAAA-MM-DD' : null,
        suffixIcon: f.kind == 'date'
            ? IconButton(
                tooltip: 'Seleccionar fecha',
                icon: const Icon(Icons.calendar_today_outlined, size: 19),
                onPressed: () async {
                  final first = DateTime(2000), last = DateTime(2100);
                  final parsed =
                      parseCalendarDate(controllers[f.key]!.text) ??
                      DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    firstDate: first,
                    lastDate: last,
                    initialDate: parsed.isBefore(first)
                        ? first
                        : parsed.isAfter(last)
                        ? last
                        : parsed,
                  );
                  if (date != null) {
                    controllers[f.key]!.text = date.toIso8601String().substring(
                      0,
                      10,
                    );
                  }
                },
              )
            : null,
      ),
      validator: (v) {
        if (f.required && (v == null || v.trim().isEmpty)) {
          return 'Este campo es obligatorio';
        }
        if (v != null && v.isNotEmpty) {
          if (f.kind == 'number' &&
              (num.tryParse(v) == null ||
                  !num.parse(v).isFinite ||
                  num.parse(v) < 0)) {
            return 'Ingresa un valor válido';
          }
          if (f.kind == 'date' && parseCalendarDate(v) == null) {
            return 'Ingresa una fecha válida (AAAA-MM-DD)';
          }
          if (f.kind == 'email' && !v.contains('@')) return 'Correo inválido';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 680,
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.record == null ? 'Crear' : 'Editar'} · ${resourceTitles[widget.collection]}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.collection == 'companies')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          'Empieza con el nombre. Puedes completar los demás datos después.',
                          style: TextStyle(color: muted),
                        ),
                      ),
                    if (![
                      'companies',
                      'products',
                    ].contains(widget.collection)) ...[
                      DropdownButtonFormField<String>(
                        initialValue: company,
                        decoration: const InputDecoration(
                          labelText: 'Empresa *',
                        ),
                        isExpanded: true,
                        items: widget.session.companies
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['id'],
                                child: Text(c['name']),
                              ),
                            )
                            .toList(),
                        onChanged: widget.record != null ? null : chooseCompany,
                        validator: (v) =>
                            v == null ? 'Selecciona una empresa' : null,
                      ),
                      const SizedBox(height: 16),
                      if (!['projects'].contains(widget.collection)) ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey('project-$company-$project'),
                          initialValue: projects.any((p) => p['id'] == project)
                              ? project
                              : null,
                          decoration: InputDecoration(
                            labelText: widget.collection == 'contacts'
                                ? 'Proyecto (opcional)'
                                : 'Proyecto *',
                          ),
                          isExpanded: true,
                          items: projects
                              .where(
                                (p) =>
                                    company == null ||
                                    p['companyId'] == company,
                              )
                              .map(
                                (p) => DropdownMenuItem<String>(
                                  value: p['id'],
                                  child: Text(p['name']),
                                ),
                              )
                              .toList(),
                          onChanged: widget.record != null
                              ? null
                              : (v) => setState(() => project = v),
                          validator: (v) =>
                              widget.collection != 'contacts' && v == null
                              ? 'Selecciona un proyecto'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                    ...resourceFields[widget.collection]!.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: field(f),
                      ),
                    ),
                    if (widget.collection == 'contracts') ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Configurar objetivos de SLA'),
                        subtitle: const Text(
                          'Objetivos contractuales en minutos hábiles.',
                        ),
                        value: slaEnabled,
                        onChanged: (v) => setState(() => slaEnabled = v),
                      ),
                      if (slaEnabled) ...[
                        TextFormField(
                          controller: response,
                          decoration: const InputDecoration(
                            labelText: 'Primera respuesta (minutos hábiles)',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0
                              ? null
                              : 'Debe ser mayor a cero',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: resolution,
                          decoration: const InputDecoration(
                            labelText: 'Resolución (minutos hábiles)',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0
                              ? null
                              : 'Debe ser mayor a cero',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: startHour,
                                decoration: const InputDecoration(
                                  labelText: 'Hora de inicio (0–22)',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: endHour,
                                decoration: const InputDecoration(
                                  labelText: 'Hora final (1–24)',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 6,
                          children: List.generate(
                            7,
                            (i) => FilterChip(
                              label: Text(
                                [
                                  'Lun',
                                  'Mar',
                                  'Mié',
                                  'Jue',
                                  'Vie',
                                  'Sáb',
                                  'Dom',
                                ][i],
                              ),
                              selected: weekdays.contains(i + 1),
                              onSelected: (v) => setState(
                                () => v
                                    ? weekdays.add(i + 1)
                                    : weekdays.remove(i + 1),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: holidays,
                          decoration: const InputDecoration(
                            labelText: 'Festivos separados por coma',
                            hintText: '2026-12-25, 2027-01-01',
                          ),
                        ),
                      ],
                    ],
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Guardando…' : 'Guardar'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String csvCell(dynamic value) {
  var s = '${value ?? ''}';
  if (RegExp(r'^[=+\-@\t\r]').hasMatch(s)) s = "'$s";
  return '"${s.replaceAll('"', '""')}"';
}

Future<void> exportCsv(String collection, List<Json> items) async {
  final keys = items
      .expand((r) => r.keys)
      .toSet()
      .where((k) => !['sla', 'visibleTo', 'permissions'].contains(k))
      .toList();
  final data = [
    keys.map(csvCell).join(','),
    ...items.map((r) => keys.map((k) => csvCell(r[k])).join(',')),
  ].join('\r\n');
  await FileSaver.instance.saveFile(
    name: 'DTS-$collection',
    bytes: Uint8List.fromList(utf8.encode('\uFEFF$data')),
    fileExtension: 'csv',
    mimeType: MimeType.csv,
  );
}

class ResourcePage extends StatefulWidget {
  const ResourcePage({
    super.key,
    required this.session,
    required this.collection,
    required this.onScope,
  });
  final Session session;
  final String collection;
  final VoidCallback onScope;
  @override
  State<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends State<ResourcePage> {
  late Future<Json> future;
  final search = TextEditingController();
  String? cursor;
  final history = <String?>[];
  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() {
    setState(() {
      future = Api.list(widget.collection, {
        ...widget.session.filters,
        if (cursor != null) 'cursor': cursor,
        if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
      });
    });
  }

  Future<void> create([Json? record]) async {
    if (await editResource(
      context,
      widget.session,
      widget.collection,
      record: record,
    )) {
      if (mounted) reload();
    }
  }

  Future<void> details(Json r) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r['name'] ?? 'Detalle'),
        scrollable: true,
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in r.entries.where(
                  (e) =>
                      ![
                        'id',
                        'searchName',
                        'createdBy',
                        'updatedBy',
                      ].contains(e.key) &&
                      e.value != null &&
                      e.value.toString().isNotEmpty,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resourceFields[widget.collection]
                                  ?.where((f) => f.key == entry.key)
                                  .firstOrNull
                                  ?.title ??
                              entry.key,
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        SelectableText(
                          entry.value is Map
                              ? const JsonEncoder.withIndent(
                                  '  ',
                                ).convert(entry.value)
                              : label(entry.value),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (['companies', 'projects'].contains(widget.collection))
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (widget.collection == 'companies') {
                  await widget.session.selectCompany(r['id']);
                } else {
                  await widget.session.selectCompany(r['companyId']);
                  widget.session.selectProject(r['id']);
                }
                widget.onScope();
              },
              child: const Text('Ver ficha 360°'),
            ),
          if (widget.session.canManage &&
              ['contracts', 'services'].contains(widget.collection))
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                renew(r);
              },
              child: const Text('Registrar renovación'),
            ),
          if (widget.session.canManage &&
              resourceFields.containsKey(widget.collection))
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                create(r);
              },
              child: const Text('Editar'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> renew(Json record) async {
    final end = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(
        record['endDate'],
      ).add(const Duration(days: 365)),
      firstDate: DateTime.parse(record['endDate']).add(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (end == null || !mounted) return;
    if (!await confirm(
      context,
      'Registrar renovación',
      'Se conservará la vigencia anterior en el historial. Nuevo vencimiento: ${displayDate(end.toIso8601String())}.',
    )) {
      return;
    }
    try {
      await Api.call('renew', {
        'collection': widget.collection,
        'id': record['id'],
        'startDate': record['endDate'],
        'endDate': end.toIso8601String().substring(0, 10),
      });
      reload();
    } catch (e) {
      if (mounted) toast(context, readableError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeading(
        resourceTitles[widget.collection] ?? widget.collection,
        resourceDescriptions[widget.collection] ?? '',
        action:
            widget.session.canManage &&
                resourceFields.containsKey(widget.collection)
            ? FilledButton.icon(
                onPressed: () => create(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Crear registro'),
              )
            : null,
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: search,
                      decoration: const InputDecoration(
                        hintText: 'Buscar por inicio del nombre…',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) {
                        cursor = null;
                        history.clear();
                        reload();
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Buscar',
                    onPressed: () {
                      cursor = null;
                      history.clear();
                      reload();
                    },
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FutureBuilder<Json>(
                future: future,
                builder: (context, s) {
                  if (s.hasError) return ErrorPanel(s.error!, retry: reload);
                  if (!s.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    );
                  }
                  final items = jsonList(s.data!['items']);
                  return Column(
                    children: [
                      if (items.isEmpty)
                        const EmptyState(
                          title: 'Todo empieza con un primer registro',
                          message:
                              'Crea información o ajusta la empresa y el proyecto seleccionados.',
                        ),
                      ...items.map(
                        (r) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            leading: MediaQuery.sizeOf(context).width < 600
                                ? null
                                : Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: canvas,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      widget.collection == 'companies'
                                          ? Icons.business_outlined
                                          : widget.collection == 'projects'
                                          ? Icons.layers_outlined
                                          : Icons.description_outlined,
                                      color: navy,
                                    ),
                                  ),
                            title: Text(
                              r['name'] ?? 'Sin nombre',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    if (r['companyId'] != null)
                                      widget.session.companyName(
                                        r['companyId'],
                                      ),
                                    if (r['module'] != null) '${r['module']}',
                                    if (r['endDate'] != null)
                                      'Vence ${displayDate(r['endDate'])}',
                                    if (r['dueDate'] != null)
                                      displayDate(r['dueDate']),
                                    if (r['amount'] != null)
                                      money(
                                        r['amount'],
                                        r['currency'] ?? 'COP',
                                      ),
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (r['status'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: StatusBadge(r['status']),
                                  ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => details(r),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          TextButton.icon(
                            onPressed: items.isEmpty
                                ? null
                                : () async {
                                    try {
                                      await exportCsv(widget.collection, items);
                                    } catch (e) {
                                      if (context.mounted) {
                                        toast(
                                          context,
                                          readableError(e),
                                          error: true,
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.download_outlined, size: 18),
                            label: const Text('Exportar esta página'),
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton(
                                onPressed: history.isEmpty
                                    ? null
                                    : () {
                                        cursor = history.removeLast();
                                        reload();
                                      },
                                child: const Text('Anterior'),
                              ),
                              Text(
                                '${items.length} registros',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                              TextButton(
                                onPressed: s.data!['cursor'] == null
                                    ? null
                                    : () {
                                        history.add(cursor);
                                        cursor = s.data!['cursor'];
                                        reload();
                                      },
                                child: const Text('Siguiente'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
