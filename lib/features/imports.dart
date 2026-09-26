import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'resources.dart';

class ImportsPage extends StatefulWidget {
  const ImportsPage({super.key, required this.session});
  final Session session;
  @override
  State<ImportsPage> createState() => _ImportsPageState();
}

class _ImportsPageState extends State<ImportsPage> {
  final url = TextEditingController(), installation = TextEditingController();
  bool busy = false;
  String? error;
  Json? preview;
  final selected = <String>{};
  final names = <String, TextEditingController>{},
      descriptions = <String, TextEditingController>{};
  final published = <String, bool>{};
  @override
  void dispose() {
    url.dispose();
    installation.dispose();
    for (final c in [...names.values, ...descriptions.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> inspect({bool local = false}) async {
    final s = widget.session;
    if (s.companyId == null || s.projectId == null) {
      toast(
        context,
        'Selecciona la empresa y el proyecto en la barra superior.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      Json data;
      if (local) {
        final result = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (result == null) return;
        if ((await result.length() ?? 1500001) > 1500000) {
          throw const FormatException('Archivo demasiado grande');
        }
        data = jsonMap(jsonDecode(utf8.decode(await result.readAsBytes())));
        data['companyId'] = s.companyId;
        data['projectId'] = s.projectId;
      } else {
        data = {
          ...s.filters,
          'url': url.text.trim(),
          if (installation.text.trim().isNotEmpty)
            'installationId': installation.text.trim(),
        };
      }
      final result = await Api.call(
        local ? 'previewImport' : 'githubImport',
        data,
      );
      for (final c in [...names.values, ...descriptions.values]) {
        c.dispose();
      }
      names.clear();
      descriptions.clear();
      selected.clear();
      published.clear();
      for (final item in jsonList(result['candidates'])) {
        names[item['key']] = TextEditingController(text: item['name']);
        descriptions[item['key']] = TextEditingController(
          text: item['description'],
        );
        published[item['key']] = false;
      }
      if (mounted) setState(() => preview = result);
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> approve() async {
    if (selected.isEmpty) return;
    if (!await confirm(
      context,
      'Aprobar catálogo',
      'Se incorporarán ${selected.length} propuestas. Solo los elementos marcados para publicar serán visibles al cliente. Las reimportaciones conservarán las ediciones existentes.',
    )) {
      return;
    }
    setState(() => busy = true);
    try {
      await Api.call('approveImport', {
        'importId': preview!['id'],
        'items': selected
            .map(
              (k) => {
                'key': k,
                'name': names[k]!.text,
                'description': descriptions[k]!.text,
                'published': published[k],
                'version': '',
                'module': 'General',
              },
            )
            .toList(),
      });
      if (mounted) {
        toast(
          context,
          'Revisión aprobada. Los cambios a elementos existentes quedaron pendientes de revisión.',
        );
        setState(() => preview = null);
      }
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading(
        'Enlazar proyecto',
        'Del repositorio al catálogo, con tu aprobación.',
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusBadge('technical'),
              const SizedBox(height: 20),
              Text(
                '1. Elige dónde guardar las funcionalidades',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.session.companyName(widget.session.companyId)} / ${widget.session.projectName(widget.session.projectId)}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        editResource(context, widget.session, 'companies'),
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Crear empresa'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        editResource(context, widget.session, 'projects'),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear proyecto'),
                  ),
                ],
              ),
              const Divider(height: 40),
              Text(
                '2. Selecciona una fuente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: url,
                decoration: const InputDecoration(
                  labelText: 'Repositorio GitHub',
                  hintText: 'https://github.com/organización/repositorio',
                  prefixIcon: Icon(Icons.code),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: installation,
                decoration: const InputDecoration(
                  labelText: 'ID de instalación GitHub App (solo privados)',
                  helperText:
                      'La App requiere configuración en el servidor. Nunca pegues tokens aquí.',
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : () => inspect(),
                    icon: const Icon(Icons.link),
                    label: const Text('Analizar repositorio'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => inspect(local: true),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Importar archivo local'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SelectableText(
                'Para una carpeta local: node scripts/import-local.cjs "ruta-del-proyecto"\nLa herramienta genera un JSON revisable. No se sube el repositorio completo.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.7),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: LinearProgressIndicator(),
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
      if (preview != null) ...[
        const SizedBox(height: 28),
        Text(
          '3. Revisa y aprueba',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Las inferencias son propuestas. Valida el alcance y la versión instalada antes de publicar.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 16),
        if (jsonList(preview!['candidates']).isEmpty)
          const Card(
            child: EmptyState(
              title: 'No se detectaron funcionalidades',
              message:
                  'Puedes registrar el catálogo manualmente o incorporar documentación funcional.',
            ),
          ),
        for (final item in jsonList(preview!['candidates']))
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${item['name']}'),
                    subtitle: Text(
                      '${item['source']} · Confianza ${((item['confidence'] as num) * 100).round()} % · ${item['diff']}${item['duplicate'] == true ? ' · Posible duplicado' : ''}',
                    ),
                    value: selected.contains(item['key']),
                    onChanged: (v) => setState(
                      () => v == true
                          ? selected.add(item['key'])
                          : selected.remove(item['key']),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: names[item['key']],
                    decoration: const InputDecoration(
                      labelText: 'Nombre validado',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptions[item['key']],
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción para cliente',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publicar para el cliente'),
                    value: published[item['key']] ?? false,
                    onChanged: (v) =>
                        setState(() => published[item['key']] = v),
                  ),
                ],
              ),
            ),
          ),
        if ((preview!['missing'] as List? ?? []).isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Hay elementos que ya no aparecen en la fuente. Revisa las posibles bajas manualmente; no se eliminó el catálogo histórico.',
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: busy || selected.isEmpty ? null : approve,
            icon: const Icon(Icons.check),
            label: Text('Aprobar ${selected.length} elementos'),
          ),
        ),
      ],
      const SizedBox(height: 32),
    ],
  );
}
