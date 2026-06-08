import 'package:flutter_test/flutter_test.dart';
import 'package:convertx/converters/data_converter.dart';

void main() {
  group('CsvToListConverter', () {
    const converter = CsvToListConverter();

    test('parses simple CSV', () {
      final rows = converter.convert('a,b,c\n1,2,3\n4,5,6');
      expect(rows.length, 3);
      expect(rows[0], ['a', 'b', 'c']);
      expect(rows[1], ['1', '2', '3']);
    });

    test('handles quoted fields with commas', () {
      final rows = converter.convert('"hello, world",b\n1,2');
      expect(rows[0][0], 'hello, world');
    });

    test('handles empty input', () {
      final rows = converter.convert('');
      expect(rows, isEmpty);
    });
  });
}
