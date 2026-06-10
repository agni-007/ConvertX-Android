import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:convertx/converters/doc_converter.dart';

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

  group('DocConverter', () {
    test('TXT → PDF starts with %PDF magic', () async {
      final input = File('${tmp.path}/in.txt');
      await input.writeAsString('Hello ConvertX.\nSecond line.');
      final out = '${tmp.path}/out.pdf';
      await DocConverter.convert(input.path, out, 'pdf', {}, 'text/plain');
      final bytes = await File(out).readAsBytes();
      expect(bytes.length, greaterThan(0));
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });

    test('TXT → HTML escapes markup', () async {
      final input = File('${tmp.path}/in.txt');
      await input.writeAsString('a < b & c > d');
      final out = '${tmp.path}/out.html';
      await DocConverter.convert(input.path, out, 'html', {}, 'text/plain');
      final html = await File(out).readAsString();
      expect(html, contains('a &lt; b &amp; c &gt; d'));
      expect(html, contains('<!DOCTYPE html>'));
    });

    test('unsupported output format throws', () async {
      final input = File('${tmp.path}/in.txt');
      await input.writeAsString('x');
      await expectLater(
        DocConverter.convert(input.path, '${tmp.path}/out.doc', 'doc', {}, 'text/plain'),
        throwsA(anything),
      );
    });
  });
}
