import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/preset.dart';

const _builtinPresets = [
  {'name': 'Web image (WebP 80%)',         'output_format': 'webp', 'options': {'quality': 80}},
  {'name': 'Email PDF (A4)',               'output_format': 'pdf',  'options': {'page_size': 'A4'}},
  {'name': 'WhatsApp photo (JPG 85%)',     'output_format': 'jpg',  'options': {'quality': 85, 'resize_w': 1600}},
  {'name': 'Audio MP3 128kbps',            'output_format': 'mp3',  'options': {'audio_bitrate': '128k'}},
  {'name': 'Lossless PNG',                 'output_format': 'png',  'options': {'compress_level': 0}},
];

class PresetService {
  PresetService._();
  static final instance = PresetService._();

  late Database _db;

  Future<void> init() async {
    final dbPath = p.join(await getDatabasesPath(), 'convertx.db');
    _db = await openDatabase(dbPath, version: 1);
    await _seedBuiltins();
  }

  Future<void> _seedBuiltins() async {
    for (final p in _builtinPresets) {
      final config = jsonEncode({'output_format': p['output_format'], 'options': p['options']});
      await _db.insert('presets', {
        'name': p['name'],
        'is_builtin': 1,
        'config_json': config,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<Preset>> getAll() async {
    final rows = await _db.query('presets', orderBy: 'is_builtin DESC, name ASC');
    return rows.map((r) {
      Map<String, dynamic> config = {};
      try { config = Map<String, dynamic>.from(jsonDecode(r['config_json'] as String) as Map); } catch (_) {}
      return Preset(
        id: r['id'] as int?,
        name: r['name'] as String,
        isBuiltin: (r['is_builtin'] as int) == 1,
        outputFormat: config['output_format'] as String? ?? '',
        options: Map<String, dynamic>.from(config['options'] as Map? ?? {}),
      );
    }).toList();
  }

  Future<void> save(Preset preset) async {
    final config = jsonEncode({'output_format': preset.outputFormat, 'options': preset.options});
    if (preset.id != null) {
      await _db.update('presets', {'name': preset.name, 'config_json': config}, where: 'id = ?', whereArgs: [preset.id]);
    } else {
      await _db.insert('presets', {'name': preset.name, 'is_builtin': 0, 'config_json': config});
    }
  }

  Future<void> delete(int id) => _db.delete('presets', where: 'id = ?', whereArgs: [id]);
}
