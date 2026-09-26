import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'auth.dart';

class AccessPage extends StatefulWidget {
  const AccessPage({super.key, required this.session});
  final Session session;
  @override
  State<AccessPage> createState() => _AccessPageState();
}

class _AccessPageState extends State<AccessPage> {
  late Future<Json> future;
  final email = TextEditingController();
  String? company, error, inviteToken;
  String inviteRole = 'client';
  bool allProjects = false, busy = false, requesterOnly = false;
  final selected = <String>{};
  List<Json> projects = [];
  @override
  void initState() {
    super.initState();
    future = Api.list('users');
    company = widget.session.companyId;
    projects = widget.session.projects;
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> invite() async {
    if (company == null ||
        !email.text.contains('@') ||
        (!allProjects && selected.isEmpty)) {
      toast(context, 'Completa correo, empresa y al menos un proyecto.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await Api.call('invite', {
        'email': email.text.trim(),
        'role': inviteRole,
        'companyId': company,
        'projectIds': selected.toList(),
        'allProjects': allProjects,
        'ticketScope': requesterOnly ? 'requester' : 'project',
      });
      if (mounted) setState(() => inviteToken = r['token']);
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editUser(Json user) async {
    String role = user['role'];
    bool active = user['active'] == true;
    String? comp = company;
    bool all = false, onlyOwn = false;
    final ids = TextEditingController();
    final result = await showDialog<Json>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(user['email'] ?? 'Usuario'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    'UID: ${user['id']}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items:
                        [
                              'owner',
                              'commercial',
                              'client',
                              'technician',
                              'reader',
                            ]
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text(label(v)),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => set(() => role = v!),
                  ),
                  SwitchListTile(
                    title: const Text('Cuenta activa'),
                    value: active,
                    onChanged: (v) => set(() => active = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: comp,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Empresa para actualizar membresía',
                    ),
                    items: widget.session.companies
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c['id'],
                            child: Text(c['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() => comp = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ids,
                    decoration: const InputDecoration(
                      labelText: 'IDs de proyectos separados por coma',
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Todos los proyectos de la empresa'),
                    value: all,
                    onChanged: (v) => set(() => all = v),
                  ),
                  SwitchListTile(
                    title: const Text('Ver solo solicitudes propias'),
                    value: onlyOwn,
                    onChanged: (v) => set(() => onlyOwn = v),
                  ),
                  const Text(
                    'La membresía de esta empresa se reemplazará con esta selección. Desactivar la cuenta revoca todo su acceso.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'uid': user['id'],
                'role': role,
                'active': active,
                'companyId': ?comp,
                'projectIds': ids.text
                    .split(',')
                    .map((v) => v.trim())
                    .where((v) => v.isNotEmpty)
                    .toList(),
                'allProjects': all,
                'ticketScope': onlyOwn ? 'requester' : 'project',
                'permissions': role == 'technician' ? ['technical'] : [],
              }),
              child: const Text('Aplicar permisos'),
            ),
          ],
        ),
      ),
    );
    ids.dispose();
    if (result != null) {
      try {
        await Api.call('access', result);
        setState(() => future = Api.list('users'));
      } catch (e) {
        if (mounted) toast(context, readableError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading(
        'Usuarios y permisos',
        'Accesos explícitos, revocables y por proyecto.',
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Invitar a un usuario',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: inviteRole,
                decoration: const InputDecoration(
                  labelText: 'Rol de la cuenta nueva',
                ),
                items: ['client', 'commercial', 'technician', 'reader']
                    .map(
                      (r) => DropdownMenuItem(value: r, child: Text(label(r))),
                    )
                    .toList(),
                onChanged: (v) => setState(() => inviteRole = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo del invitado',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: company,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Empresa'),
                items: widget.session.companies
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c['id'],
                        child: Text(c['name']),
                      ),
                    )
                    .toList(),
                onChanged: (v) async {
                  setState(() {
                    company = v;
                    selected.clear();
                    projects = [];
                  });
                  try {
                    final r = await Api.list('projects', {
                      'companyId': v,
                      'limit': 100,
                    });
                    if (mounted) {
                      setState(() => projects = jsonList(r['items']));
                    }
                  } catch (e) {
                    if (mounted) setState(() => error = readableError(e));
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Acceso a todos los proyectos de la empresa'),
                value: allProjects,
                onChanged: (v) => setState(() => allProjects = v),
              ),
              if (!allProjects)
                ...projects
                    .where((p) => p['companyId'] == company)
                    .map(
                      (p) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p['name']),
                        subtitle: SelectableText(
                          p['id'],
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                        value: selected.contains(p['id']),
                        onChanged: (v) => setState(
                          () => v == true
                              ? selected.add(p['id'])
                              : selected.remove(p['id']),
                        ),
                      ),
                    ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Restringir tickets al solicitante'),
                value: requesterOnly,
                onChanged: (v) => setState(() => requesterOnly = v),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: busy ? null : invite,
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(busy ? 'Creando…' : 'Crear invitación'),
                ),
              ),
              if (inviteToken != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Invitación válida por 7 días. Compártela con la persona indicada.',
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'https://sistema-de-gestion-y-pqrs.web.app/?invite=$inviteToken',
                ),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(
                      text:
                          'https://sistema-de-gestion-y-pqrs.web.app/?invite=$inviteToken',
                    ),
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar enlace'),
                ),
              ],
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<Json>(
            future: future,
            builder: (context, s) {
              if (s.hasError) {
                return ErrorPanel(
                  s.error!,
                  retry: () => setState(() => future = Api.list('users')),
                );
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Equipo y usuarios',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ...jsonList(s.data!['items']).map(
                    (u) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: canvas,
                        child: Icon(
                          u['active'] == true
                              ? Icons.person_outline
                              : Icons.person_off_outlined,
                          color: navy,
                        ),
                      ),
                      title: Text(u['email'] ?? u['id']),
                      subtitle: Text(
                        '${label(u['role'])} · ${u['active'] == true ? 'Activo' : 'Revocado'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Editar permisos',
                        onPressed: () => editUser(u),
                        icon: const Icon(Icons.manage_accounts_outlined),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 32),
    ],
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.session});
  final Session session;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<Json> future;
  String? cursor;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() => setState(
    () => future = Api.list('notifications', {
      'limit': 50,
      if (cursor != null) 'cursor': cursor,
    }),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading(
        'Notificaciones',
        'Solicitudes, novedades y vencimientos.',
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<Json>(
            future: future,
            builder: (context, s) {
              if (s.hasError) return ErrorPanel(s.error!, retry: load);
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = jsonList(s.data!['items']);
              return Column(
                children: [
                  if (items.isEmpty)
                    const EmptyState(
                      title: 'Estás al día',
                      message:
                          'Los avisos aparecerán aquí cuando haya novedades.',
                      icon: Icons.notifications_none,
                    ),
                  ...items.map(
                    (n) => ListTile(
                      leading: Icon(
                        n['readBy']?[widget.session.uid] != null
                            ? Icons.notifications_none
                            : Icons.notifications_active_outlined,
                        color: navy,
                      ),
                      title: Text(n['body']),
                      subtitle: Text(displayDate(n['createdAt'], time: true)),
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            await Api.call('markRead', {'id': n['id']});
                            load();
                          } catch (e) {
                            if (context.mounted) {
                              toast(context, readableError(e), error: true);
                            }
                          }
                        },
                        child: const Text('Leído'),
                      ),
                    ),
                  ),
                  if (s.data!['cursor'] != null)
                    TextButton(
                      onPressed: () {
                        cursor = s.data!['cursor'];
                        load();
                      },
                      child: const Text('Siguiente página'),
                    ),
                  if (cursor != null)
                    TextButton(
                      onPressed: () {
                        cursor = null;
                        load();
                      },
                      child: const Text('Volver al inicio'),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ],
  );
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading('Mi cuenta', 'Tu identidad y métodos de acceso.'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.profile['email'],
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              StatusBadge(session.role),
              const SizedBox(height: 24),
              const Text(
                'Empresa: Desarrollo & Tecnología Santander\nZona horaria: America/Bogota\nMoneda predeterminada: COP\nEntorno: QA',
                style: TextStyle(color: muted, height: 1.8),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await googleLogin(link: true);
                    if (context.mounted) {
                      toast(
                        context,
                        'Google quedó vinculado a tu cuenta actual.',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      toast(context, readableError(e), error: true);
                    }
                  }
                },
                icon: const Icon(Icons.link),
                label: const Text('Vincular Google a esta cuenta'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
