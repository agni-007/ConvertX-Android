import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:convertx/core/validator.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('convertx_test');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<String> writeBytes(String name, List<int> bytes) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  group('Validator', () {
    test('rejects zero-byte file', () async {
      final path = await writeBytes('empty.png', []);
      final r = await Validator.validate(path);
      expect(r.status, ValidationStatus.empty);
    });

    test('detects PNG', () async {
      final path = await writeBytes('a.png',
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0, 0, 0, 0, 0]);
      final r = await Validator.validate(path);
      expect(r.detectedMime, 'image/png');
      expect(r.status, ValidationStatus.ok);
    });

    test('detects WebP via RIFF container', () async {
      final path = await writeBytes('a.webp',
          [0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x20]);
      final r = await Validator.validate(path);
      expect(r.detectedMime, 'image/webp');
      expect(r.status, ValidationStatus.ok);
    });

    test('detects WAV via RIFF container', () async {
      final path = await writeBytes('a.wav',
          [0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x41, 0x56, 0x45, 0x66, 0x6D, 0x74, 0x20]);
      final r = await Validator.validate(path);
      expect(r.detectedMime, 'audio/wav');
    });

    test('detects TIFF (little- and big-endian)', () async {
      final le = await Validator.validate(
          await writeBytes('a.tiff', [0x49, 0x49, 0x2A, 0x00, 0, 0, 0, 0]));
      expect(le.detectedMime, 'image/tiff');
      final be = await Validator.validate(
          await writeBytes('b.tif', [0x4D, 0x4D, 0x00, 0x2A, 0, 0, 0, 0]));
      expect(be.detectedMime, 'image/tiff');
    });

    test('detects HEIC via ftyp brand', () async {
      final path = await writeBytes('a.heic',
          [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63, 0, 0, 0, 0]);
      final r = await Validator.validate(path);
      expect(r.detectedMime, 'image/heic');
    });

    test('detects MP4 via ftyp brand', () async {
      final path = await writeBytes('a.mp4',
          [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D, 0, 0, 0, 0]);
      final r = await Validator.validate(path);
      expect(r.detectedMime, 'video/mp4');
    });

    test('flags extension mismatch but allows proceeding', () async {
      final path = await writeBytes('photo.png', [0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
      final r = await Validator.validate(path);
      expect(r.detectedMime, 'image/jpeg');
      expect(r.status, ValidationStatus.mismatch);
    });

    test('accepts text formats by extension', () async {
      final path = await writeBytes('notes.txt', 'hello world'.codeUnits);
      final r = await Validator.validate(path);
      expect(r.status, ValidationStatus.ok);
      expect(r.detectedMime, 'text/plain');
    });

    test('xlsx zip container resolves to spreadsheet MIME', () async {
      final path = await writeBytes('book.xlsx', [0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]);
      final r = await Validator.validate(path);
      expect(r.detectedMime,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    });

    test('rejects unknown binary format', () async {
      final path = await writeBytes('mystery.xyz', [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]);
      final r = await Validator.validate(path);
      expect(r.status, ValidationStatus.unsupported);
    });
  });
}
