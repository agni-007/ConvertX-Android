import 'package:flutter/material.dart';
import '../core/app_bus.dart';
import '../models/preset.dart';
import '../services/preset_service.dart';

class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  List<Preset> _presets = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final presets = await PresetService.instance.getAll();
    setState(() => _presets = presets);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Presets')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPreset,
        child: const Icon(Icons.add),
      ),
      body: _presets.isEmpty
          ? const Center(child: Text('No presets yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _presets.length,
              itemBuilder: (ctx, i) => _buildPreset(_presets[i]),
            ),
    );
  }

  Widget _buildPreset(Preset preset) {
    final colorScheme = Theme.of(context).colorScheme;
    final badge = preset.outputFormat.isEmpty
        ? '?'
        : preset.outputFormat.toUpperCase().substring(0, preset.outputFormat.length.clamp(0, 3));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _applyPreset(preset),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Text(badge,
              style: TextStyle(fontSize: 10, color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
        ),
        title: Text(preset.name),
        subtitle: Text('${preset.outputFormat.toUpperCase()} · Tap to apply'),
        trailing: preset.isBuiltin
            ? const Chip(label: Text('Built-in', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact)
            : IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  if (preset.id != null) {
                    await PresetService.instance.delete(preset.id!);
                    _load();
                  }
                },
              ),
      ),
    );
  }

  void _applyPreset(Preset preset) {
    AppBus.appliedPreset.value = preset;
    AppBus.navIndex.value = 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preset "${preset.name}" applied'), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _addPreset() async {
    final nameController = TextEditingController();
    String? selectedFormat;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: const Text('New Preset'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Preset name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedFormat,
            hint: const Text('Output format'),
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: ['jpg', 'png', 'bmp', 'gif', 'tiff', 'pdf', 'html', 'csv', 'xlsx', 'json', 'yaml']
                .map((f) => DropdownMenuItem(value: f, child: Text(f.toUpperCase()))).toList(),
            onChanged: (v) => setSt(() => selectedFormat = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            if (nameController.text.isNotEmpty && selectedFormat != null) {
              await PresetService.instance.save(Preset(name: nameController.text, isBuiltin: false, outputFormat: selectedFormat!));
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }
          }, child: const Text('Save')),
        ],
      ),
    ));
  }
}
