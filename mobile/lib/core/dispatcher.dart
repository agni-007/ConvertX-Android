import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/conversion_job.dart';
import '../core/validator.dart';
import '../core/temp_manager.dart';
import '../converters/image_converter.dart';
import '../converters/doc_converter.dart';
import '../converters/data_converter.dart';
import '../converters/media_converter.dart';



// WebP is input-only: the image package has no WebP encoder.
const _imageOutputFormats = {'jpg', 'jpeg', 'png', 'bmp', 'tiff', 'gif', 'pdf'};
const _docOutputFormats = {'pdf', 'html'};
const _dataOutputFormats = {'xlsx', 'csv', 'json', 'yaml'};
const _mediaOutputFormats = {'mp4', 'mkv', 'webm', 'avi', 'mov', 'mp3', 'aac', 'flac', 'wav', 'ogg'};

const _imageMimes = {
  'image/jpeg', 'image/png', 'image/gif', 'image/bmp',
  'image/webp', 'image/tiff',
};
const _videoMimes = {
  'video/mp4', 'video/x-matroska', 'video/avi', 'video/quicktime', 'video/webm',
};
const _audioMimes = {'audio/mpeg', 'audio/flac', 'audio/ogg', 'audio/wav', 'audio/aac'};
const _dataMimes = {
  'text/csv', 'application/json',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};
const _textMimes = {
  'text/plain', 'text/html', 'text/markdown', 'text/csv', 'text/x-yaml',
  'application/json',
};

class Dispatcher {
  static Future<JobResult> dispatch(ConversionJob job) async {
    final start = DateTime.now();

    // Validate
    final validation = await Validator.validate(job.inputPath);
    if (validation.status == ValidationStatus.empty) {
      return JobResult.failed(jobId: job.id, errorCode: 'EMPTY_FILE', errorMessage: 'File is empty.');
    }
    if (validation.status == ValidationStatus.unsupported) {
      return JobResult.failed(jobId: job.id, errorCode: 'UNSUPPORTED', errorMessage: validation.message);
    }

    // Resolve output path (collision-safe)
    final outputDir = await _resolveOutputDir();
    final rawOut = p.join(outputDir, '${p.basenameWithoutExtension(job.inputName)}.${job.outputFormat}');
    final finalOut = _collisionSafePath(rawOut);

    // Allocate temp path
    final tempOut = await TempManager.instance.newTempPath('.${job.outputFormat}');

    try {
      final mime = validation.detectedMime;
      final fmt = job.outputFormat.toLowerCase();

      // HEIC decodes only via native codecs — not available in pure Dart.
      if (mime == 'image/heic' || mime == 'image/heif') {
        await TempManager.instance.purge(tempOut);
        return JobResult.failed(jobId: job.id, errorCode: 'NO_CONVERTER', errorMessage: 'HEIC input is not supported on this build. Convert to JPG in the camera app first.');
      }

      // Route to correct converter
      if (_imageMimes.contains(mime) && _imageOutputFormats.contains(fmt)) {
        await ImageConverter.convert(job.inputPath, tempOut, fmt, job.options);
      } else if ((_videoMimes.contains(mime) || _audioMimes.contains(mime)) && _mediaOutputFormats.contains(fmt)) {
        await MediaConverter.convert(job.inputPath, tempOut, fmt, job.options);
      } else if (_dataMimes.contains(mime) && _dataOutputFormats.contains(fmt)) {
        await DataConverter.convert(job.inputPath, tempOut, fmt, job.options);
      } else if (_textMimes.contains(mime) && _docOutputFormats.contains(fmt)) {
        await DocConverter.convert(job.inputPath, tempOut, fmt, job.options, mime);
      } else {
        await TempManager.instance.purge(tempOut);
        return JobResult.failed(jobId: job.id, errorCode: 'NO_CONVERTER', errorMessage: 'No converter for ${job.inputFormat} → ${job.outputFormat}');
      }

      // Verify output
      final tempFile = File(tempOut);
      if (!await tempFile.exists() || await tempFile.length() == 0) {
        await TempManager.instance.purge(tempOut);
        return JobResult.failed(jobId: job.id, errorCode: 'EMPTY_OUTPUT', errorMessage: 'Converter produced empty output.');
      }

      // Move temp → final
      await tempFile.copy(finalOut);
      await TempManager.instance.purge(tempOut);

      final size = await File(finalOut).length();
      final ms = DateTime.now().difference(start).inMilliseconds;
      return JobResult.succeeded(jobId: job.id, outputPath: finalOut, outputSizeBytes: size, durationMs: ms);

    } catch (e) {
      await TempManager.instance.purge(tempOut);
      // Never leave partial output at the destination (NFR-AND-002).
      try {
        final partial = File(finalOut);
        if (await partial.exists()) await partial.delete();
      } catch (_) {}
      final ms = DateTime.now().difference(start).inMilliseconds;
      return JobResult.failed(jobId: job.id, errorCode: 'CONVERTER_ERROR', errorMessage: e.toString(), durationMs: ms);
    }
  }

  static Future<String> _resolveOutputDir() async {
    // Write to app external files directory (visible in Files app)
    final dir = Directory('/storage/emulated/0/Download/ConvertX');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  static String _collisionSafePath(String path) {
    if (!File(path).existsSync()) return path;
    final dir = p.dirname(path);
    final ext = p.extension(path);
    final stem = p.basenameWithoutExtension(path);
    int n = 1;
    while (true) {
      final candidate = p.join(dir, '${stem}_($n)$ext');
      if (!File(candidate).existsSync()) return candidate;
      n++;
    }
  }
}
