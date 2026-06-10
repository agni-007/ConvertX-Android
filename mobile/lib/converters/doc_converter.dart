import 'dart:io';
import 'dart:isolate';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class DocConverter {
  static Future<void> convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    Map<String, dynamic> options,
    String inputMime,
  ) async {
    // Run in isolate to keep UI thread free (FR-AND-011)
    await Isolate.run(() => _convert(inputPath, outputPath, outputFormat, options, inputMime));
  }

  static Future<void> _convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    Map<String, dynamic> options,
    String inputMime,
  ) async {
    switch (outputFormat) {
      case 'pdf':
        await _toPdf(inputPath, outputPath, options, inputMime);
      case 'html':
        await _toHtml(inputPath, outputPath, options);
      default:
        throw Exception('Unsupported doc output format: $outputFormat');
    }
  }

  static Future<void> _toPdf(
    String inputPath,
    String outputPath,
    Map<String, dynamic> options,
    String inputMime,
  ) async {
    final content = await File(inputPath).readAsString();
    final pdf = pw.Document();
    final pageFormat = options['page_size'] == 'Letter' ? PdfPageFormat.letter : PdfPageFormat.a4;

    pdf.addPage(pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        pw.Text(
          content,
          style: const pw.TextStyle(fontSize: 11),
        ),
      ],
    ));

    final bytes = await pdf.save();
    await File(outputPath).writeAsBytes(bytes);
  }

  static Future<void> _toHtml(
    String inputPath,
    String outputPath,
    Map<String, dynamic> options,
  ) async {
    final content = await File(inputPath).readAsString();
    final html = '''<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Converted</title></head>
<body><pre style="font-family:monospace;white-space:pre-wrap">${_escapeHtml(content)}</pre></body>
</html>''';
    await File(outputPath).writeAsString(html);
  }

  static String _escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
