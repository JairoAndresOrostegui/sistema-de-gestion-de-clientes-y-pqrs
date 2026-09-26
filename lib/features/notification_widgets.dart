import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/notifications.dart';
import '../core/widgets.dart';
import 'tickets.dart';

String deliveryLabel(dynamic value) =>
    const {
      'accepted': 'Aceptado por Firebase',
      'historical': 'Histórico sin reenvío push',
      'no_device': 'Sin destino activo',
      'permission_denied': 'Sin permiso push',
      'invalid_token': 'Destino vencido',
      'failed': 'Envío fallido',
      'retry': 'Reintento pendiente',
      'processing': 'Enviando',
      'cancelled': 'Envío cancelado',
    }[value] ??
    'Pendiente';

class DeliverySummary extends StatelessWidget {
  const DeliverySummary(this.deliveries, {super.key});
  final dynamic deliveries;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: jsonList(deliveries)
        .map(
          (d) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${d['slot'] == 'web' ? 'Web' : 'Celular'}: ${deliveryLabel(d['status'])}'
              '${d['receivedAt'] != null ? ' · recibido ${displayDate(d['receivedAt'], time: true)}' : ''}'
              '${d['openedAt'] != null ? ' · abierto ${displayDate(d['openedAt'], time: true)}' : ''}'
              '${d['readAt'] != null ? ' · leído ${displayDate(d['readAt'], time: true)}' : ''}'
              '${d['attempts'] != null ? ' · intentos: ${d['attempts']}' : ''}',
            ),
          ),
        )
        .toList(),
  );
}

Future<void> openNotification(
  BuildContext context,
  Session session,
  String id, {
  bool push = false,
}) async {
  try {
    final notice = await Api.call('notificationDetail', {'id': id});
    if (push) {
      try {
        await Api.call('notificationReceipt', {'id': id, 'kind': 'opened'});
      } catch (_) {}
    }
    await Api.call('markRead', {'id': id});
    if (!context.mounted) return;
    if (notice['ticketId'] != null) {
      openTicket(context, session, notice['ticketId']);
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Notificación'),
          content: SingleChildScrollView(
            child: Text(notice['body'] ?? 'Novedad en DTS'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    if (context.mounted) toast(context, readableError(e), error: true);
  }
}

class DevicesCard extends StatefulWidget {
  const DevicesCard({super.key});
  @override
  State<DevicesCard> createState() => _DevicesCardState();
}

class _DevicesCardState extends State<DevicesCard> {
  late Future<Json> future = Api.call('myDevices');
  bool busy = false;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mis últimos dispositivos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Conservamos un destino web y uno celular. Al iniciar sesión en otro dispositivo del mismo tipo, los avisos nuevos se dirigirán al último.',
          ),
          const SizedBox(height: 12),
          FutureBuilder<Json>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorPanel(
                  snapshot.error!,
                  retry: () {
                    setState(() {
                      future = Api.call('myDevices');
                    });
                  },
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final items = jsonList(snapshot.data!['items']);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ['web', 'mobile'].map((slot) {
                  final match = items
                      .where((d) => d['slot'] == slot)
                      .firstOrNull;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '${slot == 'web' ? 'Web' : 'Celular'}: ${match?['label'] ?? 'Sin registro'}'
                      '${match == null ? '' : '\nÚltimo acceso: ${displayDate(match['lastLoginAt'], time: true)} · ${match['enabled'] == true ? 'Push activo' : 'Push inactivo'}${match['current'] == true ? ' · Este dispositivo' : ''}'}',
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: DeviceNotifications.status,
            builder: (_, value, _) => Text(value),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    await DeviceNotifications.enable();
                    if (mounted) {
                      setState(() {
                        busy = false;
                        future = Api.call('myDevices');
                      });
                    }
                  },
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(
              busy
                  ? 'Activando…'
                  : 'Activar notificaciones en este dispositivo',
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                future = Api.call('myDevices');
              });
            },
            child: const Text('Actualizar dispositivos'),
          ),
        ],
      ),
    ),
  );
}

class TicketNotificationTrace extends StatefulWidget {
  const TicketNotificationTrace({super.key, required this.ticketId});
  final String ticketId;
  @override
  State<TicketNotificationTrace> createState() =>
      _TicketNotificationTraceState();
}

class _TicketNotificationTraceState extends State<TicketNotificationTrace> {
  String? cursor;
  late Future<Json> future = load();
  Future<Json> load() => Api.call('ticketNotifications', {
    'ticketId': widget.ticketId,
    if (cursor != null) 'cursor': cursor,
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Trazabilidad de notificaciones'),
    content: SizedBox(
      width: 640,
      child: SingleChildScrollView(
        child: FutureBuilder<Json>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorPanel(
                snapshot.error!,
                retry: () {
                  setState(() {
                    future = load();
                  });
                },
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final items = jsonList(snapshot.data!['items']);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'El historial conserva los eventos y sus destinos. “Aceptado por Firebase” no confirma la recepción. La apertura y lectura se muestran cuando el dispositivo las confirma.',
                ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sin eventos de notificación para mostrar.'),
                  ),
                ...items.map(
                  (e) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      e['body'],
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${displayDate(e['createdAt'], time: true)} · ${e['device']?['label'] ?? 'Origen sin dispositivo registrado'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    children: [
                      Text(e['body']),
                      if (jsonList(e['recipients']).isEmpty)
                        const Text('Preparando destinatarios…'),
                      ...jsonList(e['recipients']).map(
                        (n) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(n['recipient']),
                              Text(
                                n['readAt'] == null
                                    ? 'Lectura sin confirmar'
                                    : 'Leído: ${displayDate(n['readAt'], time: true)}',
                              ),
                              DeliverySummary(n['deliveries']),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (snapshot.data!['cursor'] != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        cursor = snapshot.data!['cursor'];
                        future = load();
                      });
                    },
                    child: const Text('Siguiente página'),
                  ),
                if (cursor != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        cursor = null;
                        future = load();
                      });
                    },
                    child: const Text('Volver al inicio'),
                  ),
              ],
            );
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          setState(() {
            future = load();
          });
        },
        child: const Text('Actualizar'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );
}
