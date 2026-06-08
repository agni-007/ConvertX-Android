import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';

class DataConverter {
  static Future<void> convert(
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
        if (bytes != null) await File(outputPath).writeAsBytes(bytes);
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
          final lines = [headers.join(',')];
          for (final row in data) {
            lines.add(headers.map((h) => _csvCell((row as Map)[h])).join(','));
          }
          await File(outputPath).writeAsString(lines.join('\n'));
        } else {
          await File(outputPath).writeAsString(data.toString());
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
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _toYaml(dynamic value, int indent) {
    final pad = '  ' * indent;
    if (value is Map) {
      return value.entries.map((e) {
        final v = e.value;
        if (v is Map || v is List) return '$pad${e.key}:\n${_toYaml(v, indent + 1)}';
        return '$pad${e.key}: ${_toYaml(v, 0)}';
      }).join('\n');
    }
    if (value is List) {
      return value.map((e) => '$pad- ${_toYaml(e, 0)}').join('\n');
    }
    if (value is String && (value.contains(':') || value.contains('#') || value.isEmpty)) {
      return '"$value"';
    }
    return value?.toString() ?? 'null';
  }
}

class CsvToListConverter {
  const CsvToListConverter();

  List<List<dynamic>> convert(String csv) {
    final rows = <List<dynamic>>[];
    for (final line in csv.split('\n')) {
      if (line.trim().isEmpty) continue;
      rows.add(_parseLine(line));
    }
    return rows;
  }

  List<dynamic> _parseLine(String line) {
    final fields = <dynamic>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"'); i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        fields.add(sb.toString()); sb.clear();
      } else {
        sb.write(c);
      }
    }
    fields.add(sb.toString());
    return fields;
  }
}
