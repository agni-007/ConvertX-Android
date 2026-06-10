import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TempManager {
  TempManager._();
  static final instance = TempManager._();

  Directory? _tempDir;
  final _tracked = <String>{};

  Future<Directory> _dir() async {
    final existing = _tempDir;
    if (existing != null && existing.existsSync()) return existing;
    final cacheDir = await getTemporaryDirectory();
    final dir = Directory(p.join(cacheDir.path, 'convertx_tmp'));
    await dir.create(recursive: true);
    _tempDir = dir;
    return dir;
  }

  Future<void> init() async {
    await _dir();
  }

  Future<String> newTempPath(String suffix) async {
    final dir = await _dir();
    final name = '${DateTime.now().microsecondsSinceEpoch}$suffix';
    final path = p.join(dir.path, name);
    _tracked.add(path);
    return path;
  }

  Future<void> release(String path) async {
    _tracked.remove(path);
  }

  Future<void> purge(String path) async {
    _tracked.remove(path);
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Deletes tracked temp files and any crash leftovers from previous runs
  /// (FR-AND-012, NFR-AND-003).
  Future<void> purgeAll() async {
    for (final path in List<String>.from(_tracked)) {
      await purge(path);
    }
    try {
      final dir = await _dir();
      await for (final entity in dir.list()) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
  }
}
