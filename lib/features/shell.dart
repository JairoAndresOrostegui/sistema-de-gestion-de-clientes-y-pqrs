import '../core/notifications.dart';
import 'notification_widgets.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'admin.dart';
import 'imports.dart';
import 'resources.dart';
import 'tickets.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session});
  final Session session;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String page = 'dashboard';
  int revision = 0;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(changed);
    DeviceNotifications.incoming.addListener(incoming);
    WidgetsBinding.instance.addPostFrameCallback((_) => incoming());
  }

  @override
  void dispose() {
    widget.session.removeListener(changed);
    DeviceNotifications.incoming.removeListener(incoming);
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() => revision++);
  }

  void incoming() {
    final event = DeviceNotifications.incoming.value;
    if (!mounted || event == null) return;
    DeviceNotifications.incoming.value = null;
    if (event['opened'] == true) {
      openNotification(context, widget.session, event['id'], push: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tienes una nueva notificación en DTS'),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => openNotification(
              context,
              widget.session,
              event['id'],
              push: true,
            ),
          ),
        ),
      );
    }
  }

  List<(String, String, IconData)> get destinations => [
    ('dashboard', 'Resumen', Icons.space_dashboard_outlined),
    ('tickets', 'Solicitudes y PQRS', Icons.forum_outlined),
    if (widget.session.staff)
      ('companies', 'Empresas', Icons.business_outlined),
    ('projects', 'Proyectos', Icons.layers_outlined),
    ('installations', 'Instalaciones y versiones', Icons.devices_outlined),
    if (widget.session.staff)
      ('products', 'Productos y soluciones', Icons.inventory_2_outlined),
    if (widget.session.staff)
      ('contacts', 'Personas y estructura', Icons.account_tree_outlined),
    ('catalog', 'Catálogo funcional', Icons.widgets_outlined),
    (
      widget.session.staff ? 'contracts' : 'publicContracts',
      'Contratos y cobertura',
      Icons.description_outlined,
    ),
    (
      widget.session.staff ? 'services' : 'publicServices',
      'Servicios y renovaciones',
      Icons.dns_outlined,
    ),
    ('events', 'Implementación y agenda', Icons.event_available_outlined),
    ('articles', 'Base de conocimientos', Icons.menu_book_outlined),
    if (widget.session.staff)
      ('finance', 'Valores y movimientos', Icons.payments_outlined),
    if (widget.session.technical) ('imports', 'Enlazar proyecto', Icons.link),
    if (widget.session.owner)
      ('access', 'Usuarios y permisos', Icons.admin_panel_settings_outlined),
    ('notifications', 'Notificaciones', Icons.notifications_none),
    ('account', 'Mi cuenta', Icons.settings_outlined),
  ];
  void navigate(String target) {
    setState(() => page = target);
  }

  Widget side({bool drawer = false}) => Container(
    width: 256,
    color: navy,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(26, 30, 24, 28),
            child: Brand(light: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Text(
              widget.session.staff
                  ? 'ESPACIO DE TRABAJO'
                  : 'PORTAL DEL CLIENTE',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: destinations
                  .map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        selected: page == d.$1,
                        selectedTileColor: Colors.white.withValues(alpha: .12),
                        leading: Icon(
                          d.$3,
                          size: 20,
                          color: page == d.$1 ? gold : Colors.white60,
                        ),
                        title: Text(
                          d.$2,
                          style: TextStyle(
                            color: page == d.$1 ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: page == d.$1
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        onTap: () {
                          if (drawer) Navigator.pop(context);
                          navigate(d.$1);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_outlined, color: gold, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'QA · Entorno de pruebas',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 16, 20),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: gold,
                  child: Icon(Icons.person_outline, color: navy, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.session.roleName,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: DeviceNotifications.signOut,
                  icon: const Icon(
                    Icons.logout,
                    color: Colors.white54,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget content() {
    final s = widget.session;
    final key = ValueKey('$page-$revision');
    return switch (page) {
      'dashboard' => DashboardPage(key: key, session: s, navigate: navigate),
      'tickets' => TicketsPage(key: key, session: s),
      'imports' => ImportsPage(key: key, session: s),
      'access' => AccessPage(key: key, session: s),
      'notifications' => NotificationsPage(key: key, session: s),
      'account' => AccountPage(session: s),
      _ => ResourcePage(
        key: key,
        session: s,
        collection: page,
        onScope: () => navigate('dashboard'),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1080;
    return Scaffold(
      drawer: wide ? null : Drawer(width: 256, child: side(drawer: true)),
      body: Row(
        children: [
          if (wide) side(),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(wide ? 30 : 12, 16, 24, 16),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        if (!wide)
                          Builder(
                            builder: (ctx) => IconButton(
                              tooltip: 'Abrir menú',
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                              icon: const Icon(Icons.menu),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            'DTS / ${destinations.where((d) => d.$1 == page).firstOrNull?.$2 ?? 'Resumen'}',
                            style: const TextStyle(color: muted, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Notificaciones',
                          onPressed: () => navigate('notifications'),
                          icon: const Icon(Icons.notifications_none),
                        ),
                        const SizedBox(width: 8),
                        const StatusBadge('QA'),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 32 : 16),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1500),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: 280,
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'company-${widget.session.companyId}-${widget.session.companies.length}',
                                    ),
                                    initialValue: widget.session.companyId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Empresa',
                                      prefixIcon: Icon(
                                        Icons.business_outlined,
                                        size: 19,
                                      ),
                                    ),
                                    items: [
                                      if (widget.session.staff)
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('Todas las empresas'),
                                        ),
                                      ...widget.session.companies.map(
                                        (c) => DropdownMenuItem<String>(
                                          value: c['id'],
                                          child: Text(c['name']),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) async {
                                      try {
                                        await widget.session.selectCompany(v);
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
                                  ),
                                ),
                                SizedBox(
                                  width: 280,
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'project-${widget.session.companyId}-${widget.session.projectId}-${widget.session.projects.length}',
                                    ),
                                    initialValue: widget.session.projectId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Proyecto',
                                      prefixIcon: Icon(
                                        Icons.layers_outlined,
                                        size: 19,
                                      ),
                                    ),
                                    items: [
                                      if (widget.session.staff)
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('Todos los proyectos'),
                                        ),
                                      ...widget.session.projects.map(
                                        (p) => DropdownMenuItem<String>(
                                          value: p['id'],
                                          child: Text(p['name']),
                                        ),
                                      ),
                                    ],
                                    onChanged: widget.session.selectProject,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            content(),
                            const SizedBox(height: 32),
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text(
                              'Desarrollo & Tecnología Santander  ·  America/Bogota',
                              style: TextStyle(color: muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.session,
    required this.navigate,
  });
  final Session session;
  final void Function(String) navigate;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<List<Json>> future;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() => setState(() {
    future = Future.wait([
      Api.call('dashboard', widget.session.filters),
      Api.list('tickets', {...widget.session.filters, 'limit': 5}),
      Api.list('events', {...widget.session.filters, 'limit': 4}),
      Api.list(widget.session.staff ? 'services' : 'publicServices', {
        ...widget.session.filters,
        'limit': 5,
      }),
    ]);
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeading(
        widget.session.companyId != null
            ? 'Tu operación, en un vistazo'
            : 'Hola, ${widget.session.owner ? 'Jairo' : 'bienvenido'}',
        'Un buen día para hacer avanzar tus proyectos.',
        action: FilledButton.icon(
          onPressed: () async {
            final id = await newTicket(context, widget.session);
            if (id != null && context.mounted) {
              openTicket(context, widget.session, id);
              load();
            }
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nueva solicitud'),
        ),
      ),
      Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [navy, Color(0xFF126294)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONEXIONES QUE IMPULSAN',
                    style: TextStyle(
                      color: gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.session.companyId == null
                        ? 'Más contexto. Mejor servicio.'
                        : widget.session.companyName(widget.session.companyId),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tus clientes, proyectos y compromisos en un mismo lugar.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (MediaQuery.sizeOf(context).width > 650)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.hub_outlined, size: 64, color: gold),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      FutureBuilder<List<Json>>(
        future: future,
        builder: (context, s) {
          if (s.hasError) return ErrorPanel(s.error!, retry: load);
          if (!s.hasData) {
            return const Padding(
              padding: EdgeInsets.all(64),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final metrics = s.data![0],
              tickets = jsonList(s.data![1]['items']),
              events = jsonList(s.data![2]['items']),
              services = jsonList(s.data![3]['items']);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  final width = c.maxWidth;
                  final cardWidth =
                      width < 500 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.4
                      ? width
                      : width >= 850
                      ? (width - 48) / 4
                      : (width - 16) / 2;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final metric in [
                        (
                          'Solicitudes abiertas',
                          'open',
                          Icons.forum_outlined,
                          navy,
                        ),
                        (
                          'Por clasificar',
                          'new',
                          Icons.inbox_outlined,
                          const Color(0xFFB88213),
                        ),
                        (
                          'Proyectos activos',
                          'activeProjects',
                          Icons.layers_outlined,
                          const Color(0xFF168068),
                        ),
                        (
                          'Resueltas / Cerradas',
                          'resolved',
                          Icons.task_alt,
                          const Color(0xFF6941C6),
                        ),
                      ])
                        SizedBox(
                          width: cardWidth,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          metric.$1,
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        metric.$3,
                                        size: 20,
                                        color: metric.$4,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    '${metrics[metric.$2] ?? 0}',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: metric.$4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'En el ámbito seleccionado',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Solicitudes para seguir de cerca',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          TextButton(
                            onPressed: () => widget.navigate('tickets'),
                            child: const Text('Ver todas →'),
                          ),
                        ],
                      ),
                      if (tickets.isEmpty)
                        EmptyState(
                          title: 'Tu mesa de ayuda está lista',
                          message:
                              'Crea tu primera solicitud para iniciar el seguimiento.',
                          action: TextButton(
                            onPressed: () => widget.navigate('tickets'),
                            child: const Text('Ir a solicitudes'),
                          ),
                        ),
                      ...tickets.map(
                        (t) => TicketRow(
                          ticket: t,
                          session: widget.session,
                          onTap: () =>
                              openTicket(context, widget.session, t['id']),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, c) {
                  final panels = [
                    _DashboardPanel(
                      title: 'Próximos compromisos',
                      icon: Icons.event_available_outlined,
                      empty: 'Sin compromisos registrados.',
                      action: () => widget.navigate('events'),
                      children: events
                          .map(
                            (e) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.event_outlined,
                                color: navy,
                              ),
                              title: Text(e['name']),
                              subtitle: Text(
                                '${label(e['type'])} · ${displayDate(e['dueDate'])}',
                              ),
                              trailing: StatusBadge(e['status']),
                            ),
                          )
                          .toList(),
                    ),
                    _DashboardPanel(
                      title: 'Servicios y vigencias',
                      icon: Icons.autorenew_outlined,
                      empty: 'Registra servicios para seguir sus vigencias.',
                      action: () => widget.navigate(
                        widget.session.staff ? 'services' : 'publicServices',
                      ),
                      children: services
                          .map(
                            (e) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.dns_outlined,
                                color: navy,
                              ),
                              title: Text(e['name']),
                              subtitle: Text(
                                'Vence ${displayDate(e['endDate'])}',
                              ),
                              trailing: StatusBadge(
                                DateTime.tryParse(e['endDate'] ?? '')?.isBefore(
                                          DateTime.now().toUtc().subtract(
                                            const Duration(hours: 5),
                                          ),
                                        ) ==
                                        true
                                    ? 'vencido'
                                    : e['status'],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ];
                  return c.maxWidth < 800
                      ? Column(
                          children: [
                            panels[0],
                            const SizedBox(height: 24),
                            panels[1],
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: panels[0]),
                            const SizedBox(width: 24),
                            Expanded(child: panels[1]),
                          ],
                        );
                },
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.icon,
    required this.empty,
    required this.action,
    required this.children,
  });
  final String title, empty;
  final IconData icon;
  final VoidCallback action;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Ver registros',
                onPressed: action,
                icon: const Icon(Icons.arrow_outward, size: 19),
              ),
            ],
          ),
          if (children.isEmpty)
            EmptyState(title: 'Todo por organizar', message: empty, icon: icon),
          ...children,
        ],
      ),
    ),
  );
}
