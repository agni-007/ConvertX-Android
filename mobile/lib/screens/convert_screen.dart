import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:open_filex/open_filex.dart';
import '../core/dispatcher.dart';
import '../models/conversion_job.dart';
import '../services/history_service.dart';

const _uuid = Uuid();

const _formatGroups = {
  'Images': ['jpg', 'png', 'webp', 'bmp', 'gif', 'tiff', 'pdf'],
  'Documents': ['pdf', 'html'],
  'Data': ['xlsx', 'csv', 'json'],
  'Video': ['mp4', 'mkv', 'webm', 'avi', 'mov'],
  'Audio': ['mp3', 'aac', 'flac', 'wav', 'ogg'],
};

class _FileEntry {
  final String path;
  final String name;
  JobStatus status;
  double progress;
  String message;
  String? outputPath;

  _FileEntry({required this.path, required this.name})
      : status = JobStatus.pending,
        progress = 0,
        message = 'Queued';
}

class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  final _files = <_FileEntry>[];
  String? _selectedFormat;
  final _options = <String, dynamic>{};
  bool _isConverting = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ConvertX', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_files.isNotEmpty)
            IconButton(icon: const Icon(Icons.clear_all), onPressed: _clearAll, tooltip: 'Clear all'),
        ],
      ),
      body: Column(
        children: [
          if (_files.isEmpty) _buildEmptyState() else _buildFileList(),
          _buildBottomPanel(colorScheme),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Expanded(
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.upload_file_outlined, size: 72, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text('Select files to convert', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Images, documents, audio, video', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _pickFiles,
          icon: const Icon(Icons.add),
          label: const Text('Select Files'),
        ),
      ]),
    ),
  );

  Widget _buildFileList() => Expanded(
    child: ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _files.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: _isConverting ? null : _pickFiles,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add more files'),
            ),
          );
        }
        return _buildFileCard(_files[i - 1]);
      },
    ),
  );

  Widget _buildFileCard(_FileEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    Color statusColor;
    IconData statusIcon;
    switch (entry.status) {
      case JobStatus.success: statusColor = Colors.green; statusIcon = Icons.check_circle;
      case JobStatus.failed: statusColor = colorScheme.error; statusIcon = Icons.error;
      case JobStatus.processing: statusColor = colorScheme.primary; statusIcon = Icons.sync;
      default: statusColor = colorScheme.outline; statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(statusIcon, color: statusColor, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            if (entry.status == JobStatus.success && entry.outputPath != null)
              IconButton(icon: const Icon(Icons.open_in_new, size: 18), onPressed: () => OpenFilex.open(entry.outputPath!), tooltip: 'Open file', padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
          if (entry.status == JobStatus.processing) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: entry.progress / 100, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 4),
            Text(entry.message, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (entry.status == JobStatus.failed) ...[
            const SizedBox(height: 4),
            Text(entry.message, style: TextStyle(fontSize: 12, color: colorScheme.error)),
          ],
        ]),
      ),
    );
  }

  Widget _buildBottomPanel(ColorScheme colorScheme) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _selectedFormat,
            hint: const Text('Select output format'),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            items: _formatGroups.entries.expand((group) => [
              DropdownMenuItem(value: '__${group.key}', enabled: false, child: Text(group.key, style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.bold))),
              ...group.value.map((f) => DropdownMenuItem(value: f, child: Text(f.toUpperCase()))),
            ]).toList(),
            onChanged: (v) { if (v != null && !v.startsWith('__')) setState(() => _selectedFormat = v); },
          ),
        ),
      ]),
      if (_selectedFormat != null) ...[
        const SizedBox(height: 8),
        _buildOptionsRow(),
      ],
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: (_files.isNotEmpty && _selectedFormat != null && !_isConverting) ? _startConversion : null,
          icon: _isConverting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow),
          label: Text(_isConverting ? 'Converting…' : 'Convert ${_files.length} file${_files.length == 1 ? '' : 's'}'),
        ),
      ),
    ]),
  );

  Widget _buildOptionsRow() {
    final fmt = _selectedFormat!;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      if (['jpg', 'jpeg', 'webp'].contains(fmt))
        _OptionChip(label: 'Quality: ${_options['quality'] ?? 85}%', onTap: () => _showSliderDialog('quality', 'Image Quality', 10, 100, _options['quality'] ?? 85)),
      if (fmt == 'png')
        _OptionChip(label: 'Compress: ${_options['compress_level'] ?? 6}', onTap: () => _showSliderDialog('compress_level', 'Compression Level', 0, 9, _options['compress_level'] ?? 6)),
      if (['mp4', 'mkv', 'webm'].contains(fmt))
        _OptionChip(label: 'Quality: ${_options['quality_preset'] ?? 'balanced'}', onTap: () => _showPickerDialog('quality_preset', 'Video Quality', ['quality', 'balanced', 'small'])),
      if (['mp3', 'aac', 'ogg'].contains(fmt))
        _OptionChip(label: 'Bitrate: ${_options['audio_bitrate'] ?? '128k'}', onTap: () => _showPickerDialog('audio_bitrate', 'Audio Bitrate', ['64k', '128k', '192k', '320k'])),
    ]);
  }

  Future<void> _showSliderDialog(String key, String title, double min, double max, dynamic current) async {
    double val = (current as num).toDouble();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: StatefulBuilder(builder: (ctx, setSt) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${val.round()}', style: Theme.of(context).textTheme.headlineMedium),
        Slider(value: val, min: min, max: max, divisions: (max - min).round(), onChanged: (v) => setSt(() => val = v)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () { setState(() => _options[key] = val.round()); Navigator.pop(ctx); }, child: const Text('OK')),
      ],
    ));
  }

  Future<void> _showPickerDialog(String key, String title, List<String> choices) async {
    await showDialog(context: context, builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: choices.map((c) => SimpleDialogOption(
        onPressed: () { setState(() => _options[key] = c); Navigator.pop(ctx); },
        child: Text(c),
      )).toList(),
    ));
  }

  Future<void> _pickFiles() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      await Permission.manageExternalStorage.request();
    }
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        if (f.path != null) {
          _files.add(_FileEntry(path: f.path!, name: f.name));
        }
      }
    });
  }

  Future<void> _startConversion() async {
    if (_selectedFormat == null) return;
    setState(() { _isConverting = true; });

    for (final entry in _files) {
      if (entry.status == JobStatus.success) continue;
      setState(() { entry.status = JobStatus.processing; entry.progress = 0; entry.message = 'Starting…'; });

      final ext = entry.name.contains('.') ? entry.name.split('.').last.toLowerCase() : '';
      final job = ConversionJob(
        id: _uuid.v4(),
        inputPath: entry.path,
        inputName: entry.name,
        inputFormat: ext,
        outputFormat: _selectedFormat!,
        options: Map<String, dynamic>.from(_options),
      );

      final result = await Dispatcher.dispatch(job);
      await HistoryService.instance.record(job, result);

      setState(() {
        entry.status = result.success ? JobStatus.success : JobStatus.failed;
        entry.progress = result.success ? 100 : 0;
        entry.message = result.success
            ? 'Saved to ${result.outputPath}'
            : (result.errorMessage ?? 'Conversion failed');
        entry.outputPath = result.outputPath;
      });
    }

    setState(() { _isConverting = false; });
  }

  void _clearAll() => setState(() { _files.clear(); _selectedFormat = null; _options.clear(); });
}

class _OptionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OptionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(label, style: const TextStyle(fontSize: 12)),
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
  );
}
