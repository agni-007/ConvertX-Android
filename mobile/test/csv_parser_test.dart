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

    test('handles CRLF line endings without trailing carriage returns', () {
      final rows = converter.convert('a,b\r\n1,2\r\n');
      expect(rows.length, 2);
      expect(rows[1], ['1', '2']);
    });

    test('handles quoted newlines inside a field', () {
      final rows = converter.convert('"line1\nline2",b\n1,2');
      expect(rows.length, 2);
      expect(rows[0][0], 'line1\nline2');
    });

    test('handles escaped quotes', () {
      final rows = converter.convert('"say ""hi""",b');
      expect(rows[0][0], 'say "hi"');
    });

    test('keeps trailing empty field', () {
      final rows = converter.convert('a,b,\n1,2,3');
      expect(rows[0], ['a', 'b', '']);
    });

    test('skips blank lines', () {
      final rows = converter.convert('a,b\n\n1,2\n\n');
      expect(rows.length, 2);
    });
  });
}
