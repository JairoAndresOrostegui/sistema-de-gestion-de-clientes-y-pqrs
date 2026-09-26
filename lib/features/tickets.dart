import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'resources.dart';

const ticketStatuses = [
  'nuevo',
  'clasificacion',
  'esperando_cliente',
  'primer_nivel',
  'escalado',
  'analisis',
  'ejecucion',
  'resuelto',
  'cerrado',
  'reabierto',
  'cancelado',
];
const ticketCategories = [
  'peticion',
  'queja',
  'reclamo',
  'sugerencia',
  'incidente',
  'soporte',
  'consulta',
  'capacitacion',
  'mejora',
];
const ticketTransitions = <String, List<String>>{
  'nuevo': ['clasificacion', 'primer_nivel', 'cancelado'],
  'clasificacion': [
    'primer_nivel',
    'escalado',
    'esperando_cliente',
    'cancelado',
  ],
  'primer_nivel': ['esperando_cliente', 'escalado', 'resuelto', 'cancelado'],
  'escalado': ['analisis', 'primer_nivel', 'esperando_cliente'],
  'analisis': ['ejecucion', 'esperando_cliente', 'primer_nivel', 'resuelto'],
  'ejecucion': ['esperando_cliente', 'resuelto', 'escalado'],
  'esperando_cliente': [
    'clasificacion',
    'primer_nivel',
    'analisis',
    'ejecucion',
    'cancelado',
  ],
  'resuelto': ['cerrado', 'reabierto'],
  'cerrado': ['reabierto'],
  'reabierto': ['clasificacion', 'primer_nivel', 'escalado'],
  'cancelado': ['reabierto'],
};

Future<String?> newTicket(BuildContext context, Session s) =>
    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TicketForm(session: s),
    );
void openTicket(BuildContext context, Session s, String id) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketDetail(session: s, id: id),
      ),
    );

class TicketForm extends StatefulWidget {
  const TicketForm({super.key, required this.session});
  final Session session;
  @override
  State<TicketForm> createState() => _TicketFormState();
}

class _TicketFormState extends State<TicketForm> {
  final form = GlobalKey<FormState>();
  final controllers = {
    for (final key in [
      'subject',
      'description',
      'steps',
      'expected',
      'actual',
      'version',
      'environment',
      'contact',
    ])
      key: TextEditingController(),
  };
  String? company, project, feature, error;
  String category = 'soporte', impact = 'medio', visibility = 'project';
  bool busy = false;
  List<Json> projects = [], catalog = [], articles = [];
  @override
  void initState() {
    super.initState();
    company = widget.session.companyId;
    project = widget.session.projectId;
    projects = widget.session.projects;
    if (project != null) loadContext();
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> loadContext() async {
    final selectedCompany = company, selectedProject = project;
    try {
      final results = await Future.wait([
        Api.list('catalog', {
          'companyId': company,
          'projectId': project,
          'limit': 100,
        }),
        Api.list('articles', {
          'companyId': company,
          'projectId': project,
          'limit': 5,
        }),
      ]);
      if (mounted && company == selectedCompany && project == selectedProject) {
        setState(() {
          catalog = jsonList(results[0]['items']);
          articles = jsonList(results[1]['items']);
        });
      }
    } catch (e) {
      if (mounted && company == selectedCompany && project == selectedProject) {
        setState(() => error = readableError(e));
      }
    }
  }

  Future<void> create() async {
    if (busy) return;
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await Api.call('createTicket', {
        'companyId': company,
        'projectId': project,
        'category': category,
        'impact': impact,
        'visibility': visibility,
        'featureIds': feature == null ? [] : [feature],
        for (final e in controllers.entries) e.key: e.value.text.trim(),
      });
      if (mounted) Navigator.pop(context, result['id']);
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 720,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
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
                    'Nueva solicitud',
                    style: Theme.of(context).textTheme.headlineMedium,
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
                    const Text(
                      'Cuéntanos qué necesitas. Podrás adjuntar evidencias al radicar la solicitud.',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: company,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Empresa *'),
                      items: widget.session.companies
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id'],
                              child: Text(c['name']),
                            ),
                          )
                          .toList(),
                      validator: (v) =>
                          v == null ? 'Selecciona una empresa' : null,
                      onChanged: (v) async {
                        setState(() {
                          company = v;
                          project = null;
                          feature = null;
                          catalog = [];
                          articles = [];
                          projects = [];
                        });
                        try {
                          final r = await Api.list('projects', {
                            'companyId': v,
                            'limit': 100,
                          });
                          if (mounted && company == v) {
                            setState(() => projects = jsonList(r['items']));
                          }
                        } catch (e) {
                          if (mounted && company == v) {
                            setState(() => error = readableError(e));
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey('project-$company-$project'),
                      initialValue: project,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Proyecto *',
                      ),
                      items: projects
                          .where(
                            (p) => company == null || p['companyId'] == company,
                          )
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p['id'],
                              child: Text(p['name']),
                            ),
                          )
                          .toList(),
                      validator: (v) =>
                          v == null ? 'Selecciona un proyecto' : null,
                      onChanged: (v) {
                        setState(() {
                          project = v;
                          feature = null;
                          catalog = [];
                          articles = [];
                        });
                        loadContext();
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de solicitud',
                      ),
                      items: ticketCategories
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(label(v)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => category = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey('feature-$project-${catalog.length}'),
                      initialValue: feature,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Funcionalidad (opcional)',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No sé / Otra consulta'),
                        ),
                        ...catalog.map(
                          (f) => DropdownMenuItem<String>(
                            value: f['id'],
                            child: Text(f['name']),
                          ),
                        ),
                      ],
                      onChanged: (v) => feature = v,
                    ),
                    const SizedBox(height: 16),
                    if (articles.isNotEmpty) ...[
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lightbulb_outline),
                        title: const Text('Quizá estas guías te ayuden'),
                        children: articles
                            .map(
                              (a) => ListTile(
                                title: Text(a['name']),
                                subtitle: Text(
                                  a['description'],
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    for (final key in [
                      'subject',
                      'description',
                      if (category == 'incidente') ...[
                        'steps',
                        'expected',
                        'actual',
                      ],
                      'version',
                      'environment',
                      'contact',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: controllers[key],
                          maxLines:
                              [
                                'description',
                                'steps',
                                'expected',
                                'actual',
                              ].contains(key)
                              ? 3
                              : 1,
                          decoration: InputDecoration(
                            labelText: {
                              'subject': 'Asunto *',
                              'description': 'Descripción *',
                              'steps': 'Pasos para reproducir',
                              'expected': 'Resultado esperado',
                              'actual': 'Resultado real',
                              'version': 'Versión',
                              'environment': 'Ambiente',
                              'contact': 'Persona / Canal de contacto',
                            }[key],
                          ),
                          validator: (v) =>
                              ['subject', 'description'].contains(key) &&
                                  (v ?? '').trim().length <
                                      (key == 'description' ? 5 : 1)
                              ? 'Completa este campo'
                              : null,
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: impact,
                      decoration: const InputDecoration(
                        labelText: 'Impacto en tu operación',
                      ),
                      items: ['bajo', 'medio', 'alto', 'critico']
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(label(v)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => impact = v!,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Solo el solicitante y DTS'),
                      subtitle: const Text(
                        'Restringe la visibilidad dentro de tu empresa.',
                      ),
                      value: visibility == 'requester',
                      onChanged: (v) => setState(
                        () => visibility = v ? 'requester' : 'project',
                      ),
                    ),
                    const Text(
                      'DTS determina la prioridad final según el impacto y la cobertura. Puedes radicar solicitudes aunque no tengas soporte vigente.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
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
                FilledButton.icon(
                  onPressed: busy ? null : create,
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: Text(busy ? 'Radicando…' : 'Radicar solicitud'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key, required this.session});
  final Session session;
  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  late Future<Json> future;
  String? status, priority, category, cursor;
  bool mine = false, unassigned = false;
  final search = TextEditingController();
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
      future = Api.list('tickets', {
        ...widget.session.filters,
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (category != null) 'category': category,
        if (mine) 'mine': true,
        if (unassigned) 'assigneeId': '',
        if (cursor != null) 'cursor': cursor,
        if (search.text.isNotEmpty) 'search': search.text.trim(),
      });
    });
  }

  void filter(VoidCallback action) {
    action();
    cursor = null;
    history.clear();
    reload();
  }

  Future<void> create() async {
    final id = await newTicket(context, widget.session);
    if (id != null && mounted) {
      openTicket(context, widget.session, id);
      reload();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeading(
        widget.session.staff ? 'Mesa de ayuda' : 'Mis solicitudes',
        'Cada solicitud, con contexto y seguimiento.',
        action: FilledButton.icon(
          onPressed: create,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nueva solicitud'),
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: const Text('Todas'),
            selected: !mine && !unassigned && status == null,
            onSelected: (_) => filter(() {
              mine = false;
              unassigned = false;
              status = null;
            }),
          ),
          FilterChip(
            label: const Text('Mis solicitudes'),
            selected: mine,
            onSelected: (v) => filter(() => mine = v),
          ),
          if (widget.session.staff)
            FilterChip(
              label: const Text('Sin asignar'),
              selected: unassigned,
              onSelected: (v) => filter(() => unassigned = v),
            ),
          for (final value in ['primer_nivel', 'escalado', 'esperando_cliente'])
            FilterChip(
              label: Text(label(value)),
              selected: status == value,
              onSelected: (v) => filter(() => status = v ? value : null),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, c) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: c.maxWidth > 700 ? 280 : c.maxWidth,
                      child: TextField(
                        controller: search,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por asunto…',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => filter(() {}),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(status),
                        initialValue: status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ...ticketStatuses.map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(label(v)),
                            ),
                          ),
                        ],
                        onChanged: (v) => filter(() => status = v),
                      ),
                    ),
                    SizedBox(
                      width: 155,
                      child: DropdownButtonFormField<String>(
                        initialValue: priority,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Prioridad',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todas'),
                          ),
                          ...['baja', 'media', 'alta', 'critica'].map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(label(v)),
                            ),
                          ),
                        ],
                        onChanged: (v) => filter(() => priority = v),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: reload,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                          title: 'No hay solicitudes en esta bandeja',
                          message:
                              'Cuando registres una solicitud, podrás seguir aquí cada avance.',
                          icon: Icons.forum_outlined,
                        ),
                      ...items.map(
                        (t) => TicketRow(
                          ticket: t,
                          session: widget.session,
                          onTap: () =>
                              openTicket(context, widget.session, t['id']),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: items.isEmpty
                                ? null
                                : () => exportCsv('solicitudes', items),
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
                                '${items.length} solicitudes',
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

class TicketRow extends StatelessWidget {
  const TicketRow({
    super.key,
    required this.ticket,
    required this.session,
    required this.onTap,
  });
  final Json ticket;
  final Session session;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: ticket['priority'] == 'critica'
                  ? Colors.red
                  : ticket['priority'] == 'alta'
                  ? Colors.orange
                  : navy.withValues(alpha: .25),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ticket['number']} · ${ticket['subject']}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  '${session.companyName(ticket['companyId'])} · ${label(ticket['category'])} · ${displayDate(ticket['createdAt'])}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(ticket['status']),
                    StatusBadge(ticket['priority']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class TicketDetail extends StatefulWidget {
  const TicketDetail({super.key, required this.session, required this.id});
  final Session session;
  final String id;
  @override
  State<TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends State<TicketDetail> {
  late Future<Json> future;
  String audience = 'public';
  String? cursor;
  final body = TextEditingController(),
      minutes = TextEditingController(text: '0');
  bool sending = false;
  List<PlatformFile> files = [];
  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    body.dispose();
    minutes.dispose();
    super.dispose();
  }

  void reload() {
    setState(() {
      future = Api.call('ticketDetail', {
        'id': widget.id,
        'audience': audience,
        if (cursor != null) 'cursor': cursor,
      });
    });
  }

  Future<void> send() async {
    if (sending) return;
    if (body.text.trim().isEmpty) {
      toast(context, 'Escribe un mensaje antes de enviar.');
      return;
    }
    if (audience != 'public' &&
        !await confirm(
          context,
          label(audience),
          'Esta nota no será visible para el cliente. ¿Deseas guardarla?',
        )) {
      return;
    }
    setState(() => sending = true);
    try {
      final attachments = <Json>[];
      for (final file in files) {
        final size = await file.length() ?? 10 * 1024 * 1024;
        if (size >= 10 * 1024 * 1024) {
          throw Exception('Adjunto demasiado grande');
        }
        final ext = file.extension?.toLowerCase();
        final mime = {
          'png': 'image/png',
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'webp': 'image/webp',
          'pdf': 'application/pdf',
          'txt': 'text/plain',
        }[ext];
        if (mime == null) throw Exception('Formato no permitido');
        final path =
            'attachments/${widget.id}/$audience/${widget.session.uid}/${DateTime.now().microsecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
        await FirebaseStorage.instance
            .ref(path)
            .putData(
              await file.readAsBytes(),
              SettableMetadata(contentType: mime),
            );
        attachments.add({'path': path, 'name': file.name, 'size': size});
      }
      await Api.call('comment', {
        'ticketId': widget.id,
        'audience': audience,
        'body': body.text.trim(),
        'attachments': attachments,
        'minutes': int.tryParse(minutes.text) ?? 0,
      });
      body.clear();
      files = [];
      minutes.text = '0';
      reload();
    } catch (e) {
      if (mounted) toast(context, readableError(e), error: true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> download(Json file) async {
    try {
      final bytes = await FirebaseStorage.instance
          .ref(file['path'])
          .getData(10 * 1024 * 1024);
      if (bytes != null) {
        await FileSaver.instance.saveFile(
          name: file['name'],
          bytes: Uint8List.fromList(bytes),
          mimeType: MimeType.other,
        );
      }
    } catch (e) {
      if (mounted) {
        toast(
          context,
          'No se pudo descargar el archivo. Revisa tus permisos y conexión.',
          error: true,
        );
      }
    }
  }

  Future<void> changeState(Json t) async {
    final choices = (ticketTransitions[t['status']] ?? [])
        .where(
          (s) =>
              widget.session.role != 'client' ||
              (t['status'] == 'resuelto' && s == 'cerrado') ||
              (['resuelto', 'cerrado'].contains(t['status']) &&
                  s == 'reabierto'),
        )
        .toList();
    if (choices.isEmpty) return;
    String selected = choices.first, priority = t['priority'];
    final reason = TextEditingController(),
        assignee = TextEditingController(text: t['assigneeId']);
    final result = await showDialog<Json>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Actualizar solicitud'),
          scrollable: true,
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Nuevo estado'),
                  items: choices
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s, child: Text(label(s))),
                      )
                      .toList(),
                  onChanged: (v) => set(() => selected = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reason,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo visible al cliente *',
                  ),
                ),
                if (widget.session.staff) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Prioridad determinada por DTS',
                    ),
                    items: ['baja', 'media', 'alta', 'critica']
                        .map(
                          (v) =>
                              DropdownMenuItem(value: v, child: Text(label(v))),
                        )
                        .toList(),
                    onChanged: (v) => priority = v!,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: assignee,
                    decoration: const InputDecoration(
                      labelText: 'UID responsable (opcional)',
                      helperText:
                          'Al escalar sin UID se asigna al propietario.',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (reason.text.trim().length < 3) {
                  toast(ctx, 'Explica el motivo del cambio.');
                  return;
                }
                Navigator.pop(ctx, {
                  'ticketId': widget.id,
                  'status': selected,
                  'reason': reason.text.trim(),
                  if (widget.session.staff) 'priority': priority,
                  if (widget.session.staff) 'assigneeId': assignee.text.trim(),
                });
              },
              child: const Text('Guardar cambio'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    assignee.dispose();
    if (result != null) {
      try {
        await Api.call('transition', result);
        reload();
      } catch (e) {
        if (mounted) toast(context, readableError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle de solicitud'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: reload,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: FutureBuilder<Json>(
      future: future,
      builder: (context, s) {
        if (s.hasError) return ErrorPanel(s.error!, retry: reload);
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final t = jsonMap(s.data!['ticket']);
        final events = jsonList(s.data!['items']);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1150),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 650 ? 16 : 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusBadge(t['status']),
                      StatusBadge(t['priority']),
                      StatusBadge(t['coverage']),
                      Text(t['number'], style: const TextStyle(color: muted)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t['subject'],
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.session.companyName(t['companyId'])} · ${widget.session.projectName(t['projectId'])} · ${displayDate(t['createdAt'], time: true)}',
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(t['description']),
                          for (final k in [
                            'steps',
                            'expected',
                            'actual',
                            'version',
                            'environment',
                            'contact',
                          ])
                            if ((t[k] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  '${{'steps': 'Pasos', 'expected': 'Esperado', 'actual': 'Resultado', 'version': 'Versión', 'environment': 'Ambiente', 'contact': 'Contacto'}[k]}: ${t[k]}',
                                ),
                              ),
                          const Divider(height: 32),
                          Text(
                            t['sla'] == null
                                ? 'Sin SLA configurado'
                                : 'Primera respuesta: ${displayDate(t['responseDue'], time: true)}\nResolución objetivo: ${displayDate(t['resolutionDue'], time: true)}${t['pausedAt'] != null ? ' · SLA pausado esperando al cliente' : ''}',
                            style: const TextStyle(color: muted),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => changeState(t),
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Actualizar estado'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Conversación y trazabilidad',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final a in [
                                'public',
                                if (widget.session.staff) 'internal',
                                if (widget.session.technical) 'technical',
                              ])
                                ChoiceChip(
                                  label: Text(label(a)),
                                  selected: audience == a,
                                  onSelected: (_) {
                                    audience = a;
                                    cursor = null;
                                    reload();
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (events.isEmpty)
                            const Text(
                              'Aún no hay mensajes en esta audiencia.',
                              style: TextStyle(color: muted),
                            ),
                          ...events.map(
                            (e) => Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: e['kind'] == 'event'
                                    ? canvas
                                    : navy.withValues(alpha: .04),
                                border: Border.all(color: line),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e['authorId'] == widget.session.uid
                                        ? 'Tú'
                                        : e['kind'] == 'event'
                                        ? 'Seguimiento DTS'
                                        : 'Participante autorizado'} · ${displayDate(e['createdAt'], time: true)}',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(e['body'] ?? ''),
                                  for (final f in jsonList(e['attachments']))
                                    TextButton.icon(
                                      onPressed: () => download(f),
                                      icon: const Icon(
                                        Icons.attach_file,
                                        size: 16,
                                      ),
                                      label: Text(f['name']),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (cursor != null)
                            TextButton(
                              onPressed: () {
                                cursor = null;
                                reload();
                              },
                              child: const Text(
                                'Volver al inicio del historial',
                              ),
                            ),
                          if (s.data!['cursor'] != null)
                            TextButton(
                              onPressed: () {
                                cursor = s.data!['cursor'];
                                reload();
                              },
                              child: const Text('Siguientes mensajes'),
                            ),
                          const Divider(height: 32),
                          Text(
                            'Audiencia: ${label(audience)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: body,
                            minLines: 3,
                            maxLines: 8,
                            decoration: InputDecoration(
                              hintText: audience == 'public'
                                  ? 'Escribe tu respuesta para el cliente…'
                                  : 'Escribe una nota reservada…',
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (files.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              children: files
                                  .map(
                                    (f) => InputChip(
                                      label: Text(f.name),
                                      onDeleted: () =>
                                          setState(() => files.remove(f)),
                                    ),
                                  )
                                  .toList(),
                            ),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: sending
                                    ? null
                                    : () async {
                                        final result =
                                            await FilePicker.pickFiles(
                                              type: FileType.custom,
                                              allowedExtensions: [
                                                'png',
                                                'jpg',
                                                'jpeg',
                                                'webp',
                                                'pdf',
                                                'txt',
                                              ],
                                            );
                                        if (result.isNotEmpty &&
                                            context.mounted) {
                                          if (result.length > 5 ||
                                              result.any(
                                                (f) =>
                                                    (f.lengthSync() ?? 0) >=
                                                    10 * 1024 * 1024,
                                              )) {
                                            toast(
                                              context,
                                              'Máximo 5 archivos, menores de 10 MB cada uno.',
                                              error: true,
                                            );
                                            return;
                                          }
                                          setState(() => files = result);
                                        }
                                      },
                                icon: const Icon(Icons.attach_file, size: 18),
                                label: const Text('Adjuntar evidencia'),
                              ),
                              if (widget.session.staff)
                                SizedBox(
                                  width: 160,
                                  child: TextField(
                                    controller: minutes,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Minutos invertidos',
                                    ),
                                  ),
                                ),
                              FilledButton.icon(
                                onPressed: sending ? null : send,
                                icon: const Icon(Icons.send_outlined, size: 18),
                                label: Text(
                                  sending ? 'Enviando…' : 'Enviar mensaje',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
