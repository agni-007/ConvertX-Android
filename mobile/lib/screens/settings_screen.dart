import 'package:flutter/material.dart';
import '../services/history_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear conversion history'),
                subtitle: const Text('Remove all history entries'),
                onTap: () async {
                  final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                    title: const Text('Clear history?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                    ],
                  ));
                  if (ok == true) await HistoryService.instance.clearAll();
                },
              ),
              const Divider(height: 0),
              const ListTile(
                leading: Icon(Icons.offline_bolt),
                title: Text('Offline mode'),
                subtitle: Text('ConvertX works 100% offline. No network access is used.'),
                trailing: Icon(Icons.check_circle, color: Colors.green),
              ),
              const Divider(height: 0),
              const ListTile(
                leading: Icon(Icons.security),
                title: Text('Privacy'),
                subtitle: Text('Files never leave your device. No analytics, no telemetry.'),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('ConvertX for Android'),
              subtitle: const Text('Version 1.0.0 · Universal file converter'),
            ),
          ),
        ],
      ),
    );
  }
}
