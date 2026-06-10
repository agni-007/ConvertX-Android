import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:convertx/converters/data_converter.dart';

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

  Future<String> write(String name, String content) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsString(content);
    return f.path;
  }

  group('DataConverter CSV', () {
    test('CSV → JSON maps headers to values', () async {
      final input = await write('in.csv', 'name,age\nalice,30\nbob,25');
      final out = '${tmp.path}/out.json';
      await DataConverter.convert(input, out, 'json', {});
      final data = jsonDecode(await File(out).readAsString()) as List;
      expect(data.length, 2);
      expect(data[0]['name'], 'alice');
      expect(data[1]['age'], '25');
    });

    test('CSV → XLSX produces a non-empty zip file', () async {
      final input = await write('in.csv', 'a,b\n1,2\n3,4');
      final out = '${tmp.path}/out.xlsx';
      await DataConverter.convert(input, out, 'xlsx', {});
      final bytes = await File(out).readAsBytes();
      expect(bytes.length, greaterThan(0));
      // XLSX is a ZIP container: PK\x03\x04
      expect(bytes.sublist(0, 4), [0x50, 0x4B, 0x03, 0x04]);
    });

    test('XLSX → CSV round-trips values', () async {
      final input = await write('in.csv', 'h1,h2\nv1,v2');
      final xlsx = '${tmp.path}/mid.xlsx';
      await DataConverter.convert(input, xlsx, 'xlsx', {});
      final out = '${tmp.path}/out.csv';
      await DataConverter.convert(xlsx, out, 'csv', {});
      final content = await File(out).readAsString();
      expect(content, contains('h1'));
      expect(content, contains('v2'));
    });
  });

  group('DataConverter JSON', () {
    test('JSON → CSV with quoting', () async {
      final input = await write('in.json', '[{"a":"x,y","b":1},{"a":"z","b":2}]');
      final out = '${tmp.path}/out.csv';
      await DataConverter.convert(input, out, 'csv', {});
      final lines = (await File(out).readAsString()).split('\n');
      expect(lines[0], 'a,b');
      expect(lines[1], '"x,y",1');
    });

    test('JSON → YAML emits valid nested structure', () async {
      final input = await write('in.json',
          '{"name":"test","items":[{"id":1,"tag":"a:b"},{"id":2}],"empty":[]}');
      final out = '${tmp.path}/out.yaml';
      await DataConverter.convert(input, out, 'yaml', {});
      final yaml = await File(out).readAsString();
      expect(yaml, contains('name: test'));
      expect(yaml, contains('- id: 1'));
      // Values with reserved chars must be quoted
      expect(yaml, contains('"a:b"'));
      expect(yaml, contains('empty: []'));
    });

    test('corrupt JSON throws and leaves no output', () async {
      final input = await write('in.json', '{not valid json');
      final out = '${tmp.path}/out.yaml';
      await expectLater(
        DataConverter.convert(input, out, 'yaml', {}),
        throwsA(anything),
      );
      expect(File(out).existsSync(), isFalse);
    });
  });
}
