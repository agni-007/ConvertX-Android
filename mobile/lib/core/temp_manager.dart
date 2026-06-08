import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TempManager {
  TempManager._();
  static final instance = TempManager._();

  late Directory _tempDir;
  final _tracked = <String>{};

  Future<void> init() async {
    final cacheDir = await getTemporaryDirectory();
    _tempDir = Directory(p.join(cacheDir.path, 'convertx_tmp'));
    await _tempDir.create(recursive: true);
  }

  Future<String> newTempPath(String suffix) async {
    await _ensureInit();
    final name = '${DateTime.now().microsecondsSinceEpoch}$suffix';
    final path = p.join(_tempDir.path, name);
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

  Future<void> purgeAll() async {
    for (final path in List<String>.from(_tracked)) {
      await purge(path);
    }
    // Also wipe the whole temp dir on startup to clean up crash leftovers
    try {
      if (_tempDir.existsSync()) {
        await for (final entity in _tempDir.list()) {
          try { await entity.delete(recursive: true); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _ensureInit() async {
    if (!_tempDir.existsSync()) await init();
  }
}
