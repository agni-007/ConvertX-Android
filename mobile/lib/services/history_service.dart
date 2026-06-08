import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/history_entry.dart';
import '../models/conversion_job.dart';

class HistoryService {
  HistoryService._();
  static final instance = HistoryService._();

  late Database _db;

  Future<void> init() async {
    final dbPath = p.join(await getDatabasesPath(), 'convertx.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            input_name TEXT NOT NULL,
            input_format TEXT NOT NULL,
            output_format TEXT NOT NULL,
            settings_json TEXT NOT NULL,
            output_size INTEGER,
            duration_ms INTEGER,
            success INTEGER NOT NULL DEFAULT 0,
            error_message TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS presets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            is_builtin INTEGER NOT NULL DEFAULT 0,
            config_json TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> record(ConversionJob job, JobResult result) async {
    await _db.insert('history', {
      'created_at': DateTime.now().toIso8601String(),
      'input_name': job.inputName,
      'input_format': job.inputFormat,
      'output_format': job.outputFormat,
      'settings_json': jsonEncode(job.options),
      'output_size': result.outputSizeBytes,
      'duration_ms': result.durationMs,
      'success': result.success ? 1 : 0,
      'error_message': result.errorMessage,
    });
    // Auto-prune: keep last 200 entries (FR-017)
    await _db.execute('''
      DELETE FROM history WHERE id NOT IN (
        SELECT id FROM history ORDER BY created_at DESC LIMIT 200
      )
    ''');
  }

  Future<List<HistoryEntry>> getRecent({int limit = 200}) async {
    final rows = await _db.query('history', orderBy: 'created_at DESC', limit: limit);
    return rows.map((r) {
      final settings = jsonDecode(r['settings_json'] as String? ?? '{}');
      return HistoryEntry(
        id: r['id'] as int?,
        createdAt: DateTime.parse(r['created_at'] as String),
        inputName: r['input_name'] as String,
        inputFormat: r['input_format'] as String,
        outputFormat: r['output_format'] as String,
        settings: Map<String, dynamic>.from(settings as Map),
        outputSize: r['output_size'] as int?,
        durationMs: r['duration_ms'] as int?,
        success: (r['success'] as int) == 1,
        errorMessage: r['error_message'] as String?,
      );
    }).toList();
  }

  Future<void> clearAll() => _db.delete('history');
}
