import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFB42318) : navy,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.value, {super.key});
  final String value;
  @override
  Widget build(BuildContext context) {
    final color =
        [
          'resuelto',
          'cerrado',
          'activo',
          'cubierto',
          'completado',
          'disponible',
        ].contains(value)
        ? const Color(0xFF12805C)
        : ['critica', 'vencido', 'fuera_cobertura', 'cancelado'].contains(value)
        ? const Color(0xFFB54708)
        : ['escalado', 'analisis', 'ejecucion'].contains(value)
        ? const Color(0xFF6941C6)
        : navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label(value),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.inbox_outlined,
  });
  final String title, message;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: canvas,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 32, color: navy),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel(this.error, {super.key, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => EmptyState(
    title: 'No pudimos cargar la información',
    message: readableError(error),
    icon: Icons.cloud_off_outlined,
    action: OutlinedButton.icon(
      onPressed: retry,
      icon: const Icon(Icons.refresh),
      label: const Text('Volver a intentar'),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      spacing: 24,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: muted)),
          ],
        ),
        ?action,
      ],
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.light = false});
  final bool light;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: gold,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.hub_outlined, color: navy, size: 26),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DTS',
              style: TextStyle(
                color: light ? Colors.white : navy,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                height: 1.1,
              ),
            ),
            Text(
              'GESTIÓN & SOPORTE',
              style: TextStyle(
                color: light ? Colors.white70 : muted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Future<bool> confirm(BuildContext context, String title, String message) =>
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ).then((v) => v ?? false);
