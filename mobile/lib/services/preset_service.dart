import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/preset.dart';

// WebP and MP3/video outputs are not available in this build (no WebP
// encoder in the image package; FFmpeg removed — see DEVLOG Error 2),
// so the built-in presets only use formats the app can actually produce.
const _builtinPresets = [
  {'name': 'Web image (JPG 80%)',      'output_format': 'jpg',  'options': {'quality': 80}},
  {'name': 'Email PDF (A4)',           'output_format': 'pdf',  'options': {'page_size': 'A4'}},
  {'name': 'WhatsApp photo (JPG 85%)', 'output_format': 'jpg',  'options': {'quality': 85, 'resize_w': 1600}},
  {'name': 'Lossless PNG',             'output_format': 'png',  'options': {'compress_level': 0}},
  {'name': 'Spreadsheet to Excel',     'output_format': 'xlsx', 'options': <String, dynamic>{}},
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
    final names = _builtinPresets.map((p) => p['name'] as String).toList();
    // Remove builtins from older versions that no longer exist
    await _db.delete(
      'presets',
      where: 'is_builtin = 1 AND name NOT IN (${List.filled(names.length, '?').join(',')})',
      whereArgs: names,
    );
    for (final preset in _builtinPresets) {
      final config = jsonEncode({'output_format': preset['output_format'], 'options': preset['options']});
      await _db.insert('presets', {
        'name': preset['name'],
        'is_builtin': 1,
        'config_json': config,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<Preset>> getAll() async {
    final rows = await _db.query('presets', orderBy: 'is_builtin DESC, name ASC');
    return rows.map((r) => Preset.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> save(Preset preset) async {
    final map = preset.toMap()..remove('id');
    if (preset.id != null) {
      map.remove('is_builtin');
      await _db.update('presets', map, where: 'id = ?', whereArgs: [preset.id]);
    } else {
      map['is_builtin'] = 0;
      await _db.insert('presets', map);
    }
  }

  Future<void> delete(int id) => _db.delete('presets', where: 'id = ?', whereArgs: [id]);
}
