import 'package:flutter/material.dart';
import '../models/history_entry.dart';
import '../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await HistoryService.instance.getRecent();
    setState(() { _entries = entries; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear history',
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Clear history?'),
                  content: const Text('This will delete all conversion history.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                  ],
                ));
                if (ok == true) { await HistoryService.instance.clearAll(); _load(); }
              },
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _entries.length,
                  itemBuilder: (ctx, i) => _buildEntry(_entries[i]),
                ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 12),
      const Text('No conversions yet'),
    ]),
  );

  Widget _buildEntry(HistoryEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.success ? Colors.green.withValues(alpha: 0.15) : colorScheme.errorContainer,
          child: Icon(
            entry.success ? Icons.check : Icons.error_outline,
            color: entry.success ? Colors.green : colorScheme.error,
            size: 20,
          ),
        ),
        title: Text(entry.inputName, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${entry.inputFormat.toUpperCase()} → ${entry.outputFormat.toUpperCase()} · ${_relativeTime(entry.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: entry.durationMs != null
            ? Text('${entry.durationMs}ms', style: TextStyle(fontSize: 11, color: colorScheme.outline))
            : null,
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
