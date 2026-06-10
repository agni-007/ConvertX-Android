import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;

class ImageConverter {
  static Future<void> convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    Map<String, dynamic> options,
  ) async {
    // Run in isolate to keep UI thread free (NFR-007)
    await Isolate.run(() => _convert(inputPath, outputPath, outputFormat, options));
  }

  static Future<void> _convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    Map<String, dynamic> options,
  ) async {
    final inputBytes = await File(inputPath).readAsBytes();
    var image = img.decodeImage(inputBytes);
    if (image == null) throw Exception('Failed to decode image: $inputPath');

    // Resize if requested
    final resizeW = options['resize_w'] as int?;
    final resizeH = options['resize_h'] as int?;
    if (resizeW != null || resizeH != null) {
      final keepAspect = options['keep_aspect'] as bool? ?? true;
      int w = resizeW ?? image.width;
      int h = resizeH ?? image.height;
      if (keepAspect) {
        if (resizeW != null && resizeH == null) {
          h = (image.height * resizeW / image.width).round();
        } else if (resizeH != null && resizeW == null) {
          w = (image.width * resizeH / image.height).round();
        }
      }
      image = img.copyResize(image, width: w, height: h, interpolation: img.Interpolation.linear);
    }

    // Strip EXIF if requested
    final stripExif = options['strip_exif'] as bool? ?? false;
    if (stripExif) {
      image = img.Image.from(image)..exif = img.ExifData();
    }

    Uint8List outputBytes;
    switch (outputFormat) {
      case 'jpg':
      case 'jpeg':
        final quality = options['quality'] as int? ?? 85;
        outputBytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case 'png':
        final level = options['compress_level'] as int? ?? 6;
        outputBytes = Uint8List.fromList(img.encodePng(image, level: level));
      case 'webp':
        // The image package decodes WebP but has no WebP encoder.
        throw UnsupportedError('WebP can be used as input but not as output format.');
      case 'bmp':
        outputBytes = Uint8List.fromList(img.encodeBmp(image));
      case 'gif':
        outputBytes = Uint8List.fromList(img.encodeGif(image));
      case 'tiff':
        outputBytes = Uint8List.fromList(img.encodeTiff(image));
      case 'pdf':
        outputBytes = await _imageToPdf(image, options);
      default:
        throw Exception('Unsupported image output format: $outputFormat');
    }

    await File(outputPath).writeAsBytes(outputBytes);
  }

  static Future<Uint8List> _imageToPdf(img.Image image, Map<String, dynamic> options) async {
    final pdf = pw.Document();
    final pdfImage = pw.MemoryImage(
      Uint8List.fromList(img.encodePng(image)),
    );
    pdf.addPage(pw.Page(
      build: (ctx) => pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
    ));
    return pdf.save();
  }
}
