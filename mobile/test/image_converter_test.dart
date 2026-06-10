import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:convertx/converters/image_converter.dart';

void main() {
  late Directory tmp;
  late String pngPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('convertx_test');
    final image = img.Image(width: 64, height: 48);
    img.fill(image, color: img.ColorRgb8(200, 60, 60));
    pngPath = '${tmp.path}/in.png';
    await File(pngPath).writeAsBytes(img.encodePng(image));
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  group('ImageConverter', () {
    test('PNG → JPG produces a decodable JPEG', () async {
      final out = '${tmp.path}/out.jpg';
      await ImageConverter.convert(pngPath, out, 'jpg', {'quality': 85});
      final decoded = img.decodeJpg(await File(out).readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.width, 64);
    });

    test('PNG → BMP, GIF, TIFF produce non-empty output', () async {
      for (final fmt in ['bmp', 'gif', 'tiff']) {
        final out = '${tmp.path}/out.$fmt';
        await ImageConverter.convert(pngPath, out, fmt, {});
        expect(await File(out).length(), greaterThan(0), reason: fmt);
      }
    });

    test('PNG → PDF starts with %PDF magic', () async {
      final out = '${tmp.path}/out.pdf';
      await ImageConverter.convert(pngPath, out, 'pdf', {});
      final bytes = await File(out).readAsBytes();
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });

    test('resize width keeps aspect ratio', () async {
      final out = '${tmp.path}/resized.png';
      await ImageConverter.convert(pngPath, out, 'png', {'resize_w': 32});
      final decoded = img.decodePng(await File(out).readAsBytes())!;
      expect(decoded.width, 32);
      expect(decoded.height, 24);
    });

    test('WebP output throws a typed error', () async {
      final out = '${tmp.path}/out.webp';
      await expectLater(
        ImageConverter.convert(pngPath, out, 'webp', {}),
        throwsA(isA<UnsupportedError>()),
      );
      expect(File(out).existsSync(), isFalse);
    });

    test('corrupt input throws and leaves no output', () async {
      final corrupt = '${tmp.path}/corrupt.png';
      await File(corrupt).writeAsBytes([1, 2, 3, 4, 5]);
      final out = '${tmp.path}/out.jpg';
      await expectLater(
        ImageConverter.convert(corrupt, out, 'jpg', {}),
        throwsA(anything),
      );
      expect(File(out).existsSync(), isFalse);
    });
  });
}
