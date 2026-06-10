import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:excel/excel.dart';

class DataConverter {
  static Future<void> convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    Map<String, dynamic> options,
  ) async {
    // Run in isolate to keep UI thread free (FR-AND-011)
    await Isolate.run(() => _convert(inputPath, outputPath, outputFormat, options));
  }

  static Future<void> _convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    Map<String, dynamic> options,
  ) async {
    final ext = inputPath.split('.').last.toLowerCase();
    switch (ext) {
      case 'csv':
        await _csvConvert(inputPath, outputPath, outputFormat, options);
      case 'json':
        await _jsonConvert(inputPath, outputPath, outputFormat, options);
      case 'xlsx':
        await _xlsxConvert(inputPath, outputPath, outputFormat, options);
      default:
        throw Exception('Unsupported data input: $ext');
    }
  }

  static Future<void> _csvConvert(
    String inputPath, String outputPath, String outputFormat, Map<String, dynamic> options,
  ) async {
    final content = await File(inputPath).readAsString();
    final rows = const CsvToListConverter().convert(content);

    switch (outputFormat) {
      case 'xlsx':
        final excel = Excel.createExcel();
        final sheet = excel['Sheet1'];
        for (final row in rows) {
          sheet.appendRow(row.map((c) => TextCellValue(c.toString())).toList());
        }
        final bytes = excel.save();
        if (bytes == null) throw Exception('Failed to encode XLSX.');
        await File(outputPath).writeAsBytes(bytes);
      case 'json':
        if (rows.isEmpty) { await File(outputPath).writeAsString('[]'); return; }
        final headers = rows.first.map((h) => h.toString()).toList();
        final data = rows.skip(1).map((row) {
          final m = <String, dynamic>{};
          for (int i = 0; i < headers.length; i++) {
            m[headers[i]] = i < row.length ? row[i] : null;
          }
          return m;
        }).toList();
        await File(outputPath).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      case 'tsv':
        final tsv = rows.map((r) => r.join('\t')).join('\n');
        await File(outputPath).writeAsString(tsv);
      default:
        throw Exception('Unsupported CSV output: $outputFormat');
    }
  }

  static Future<void> _jsonConvert(
    String inputPath, String outputPath, String outputFormat, Map<String, dynamic> options,
  ) async {
    final content = await File(inputPath).readAsString();
    final data = jsonDecode(content);

    switch (outputFormat) {
      case 'csv':
        if (data is List && data.isNotEmpty && data.first is Map) {
          final headers = (data.first as Map).keys.toList();
          final lines = [headers.map((h) => _csvCell(h)).join(',')];
          for (final row in data) {
            lines.add(headers.map((h) => _csvCell((row as Map)[h])).join(','));
          }
          await File(outputPath).writeAsString(lines.join('\n'));
        } else if (data is List) {
          await File(outputPath).writeAsString(data.map(_csvCell).join('\n'));
        } else {
          throw Exception('JSON → CSV requires a JSON array.');
        }
      case 'yaml':
        final yaml = _toYaml(data, 0);
        await File(outputPath).writeAsString(yaml);
      default:
        throw Exception('Unsupported JSON output: $outputFormat');
    }
  }

  static Future<void> _xlsxConvert(
    String inputPath, String outputPath, String outputFormat, Map<String, dynamic> options,
  ) async {
    final bytes = await File(inputPath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) throw Exception('Workbook contains no sheets.');
    final sheetName = options['sheet_name'] as String? ?? excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    if (sheet == null) throw Exception('Sheet "$sheetName" not found.');

    final rows = sheet.rows;
    switch (outputFormat) {
      case 'csv':
        final lines = rows.map((r) => r.map((c) => _csvCell(c?.value?.toString())).join(',')).toList();
        await File(outputPath).writeAsString(lines.join('\n'));
      case 'json':
        if (rows.isEmpty) { await File(outputPath).writeAsString('[]'); return; }
        final headers = rows.first.map((c) => c?.value?.toString() ?? '').toList();
        final data = rows.skip(1).map((row) {
          final m = <String, dynamic>{};
          for (int i = 0; i < headers.length; i++) {
            m[headers[i]] = i < row.length ? row[i]?.value?.toString() : null;
          }
          return m;
        }).toList();
        await File(outputPath).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      default:
        throw Exception('Unsupported XLSX output: $outputFormat');
    }
  }

  static String _csvCell(dynamic v) {
    final s = v?.toString() ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _toYaml(dynamic value, int indent) {
    final pad = '  ' * indent;
    if (value is Map) {
      if (value.isEmpty) return '$pad{}';
      return value.entries.map((e) {
        final v = e.value;
        if ((v is Map && v.isNotEmpty) || (v is List && v.isNotEmpty)) {
          return '$pad${e.key}:\n${_toYaml(v, indent + 1)}';
        }
        return '$pad${e.key}: ${_yamlScalar(v)}';
      }).join('\n');
    }
    if (value is List) {
      if (value.isEmpty) return '$pad[]';
      return value.map((e) {
        if (e is Map && e.isNotEmpty) {
          // First key goes on the dash line; '- ' is the same width as one
          // indent level, so nested lines stay aligned.
          final inner = _toYaml(e, indent + 1);
          final childPad = '  ' * (indent + 1);
          return '$pad- ${inner.substring(childPad.length)}';
        }
        if (e is List && e.isNotEmpty) {
          return '$pad-\n${_toYaml(e, indent + 1)}';
        }
        return '$pad- ${_yamlScalar(e)}';
      }).join('\n');
    }
    return '$pad${_yamlScalar(value)}';
  }

  static String _yamlScalar(dynamic v) {
    if (v == null) return 'null';
    if (v is num || v is bool) return v.toString();
    if (v is Map) return '{}';
    if (v is List) return '[]';
    final s = v.toString();
    final reserved = {'true', 'false', 'null', 'yes', 'no', 'on', 'off', '~'};
    final needsQuote = s.isEmpty ||
        s.trim() != s ||
        s.contains('\n') ||
        RegExp('[:#"\'\\[\\]{},&*?|>%@`]').hasMatch(s) ||
        s.startsWith('-') ||
        reserved.contains(s.toLowerCase()) ||
        num.tryParse(s) != null;
    if (!needsQuote) return s;
    final escaped = s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
    return '"$escaped"';
  }
}

/// Minimal RFC-4180 CSV parser: handles quoted fields, escaped quotes,
/// quoted newlines, and CRLF/CR/LF line endings.
class CsvToListConverter {
  const CsvToListConverter();

  List<List<dynamic>> convert(String csv) {
    final rows = <List<dynamic>>[];
    var fields = <dynamic>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    void endField() {
      fields.add(sb.toString());
      sb.clear();
    }

    void endRow() {
      endField();
      final isEmptyRow = fields.length == 1 && (fields[0] as String).isEmpty;
      if (!isEmptyRow) rows.add(fields);
      fields = <dynamic>[];
    }

    for (int i = 0; i < csv.length; i++) {
      final c = csv[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < csv.length && csv[i + 1] == '"') {
            sb.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          sb.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        endField();
      } else if (c == '\r') {
        if (i + 1 < csv.length && csv[i + 1] == '\n') i++;
        endRow();
      } else if (c == '\n') {
        endRow();
      } else {
        sb.write(c);
      }
    }
    if (sb.isNotEmpty || fields.isNotEmpty) endRow();
    return rows;
  }
}
