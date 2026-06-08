import 'dart:io';
import 'dart:typed_data';

enum ValidationStatus { ok, mismatch, empty, unsupported }

class ValidationResult {
  final ValidationStatus status;
  final String detectedMime;
  final String declaredExtension;
  final String message;

  const ValidationResult({
    required this.status,
    required this.detectedMime,
    required this.declaredExtension,
    this.message = '',
  });
}

class Validator {
  static const _signatures = <(int, List<int>, String, List<String>)>[
    (0, [0xFF, 0xD8, 0xFF], 'image/jpeg', ['.jpg', '.jpeg']),
    (0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], 'image/png', ['.png']),
    (0, [0x47, 0x49, 0x46, 0x38, 0x37, 0x61], 'image/gif', ['.gif']),
    (0, [0x47, 0x49, 0x46, 0x38, 0x39, 0x61], 'image/gif', ['.gif']),
    (0, [0x42, 0x4D], 'image/bmp', ['.bmp']),
    (0, [0x25, 0x50, 0x44, 0x46], 'application/pdf', ['.pdf']),
    (0, [0x50, 0x4B, 0x03, 0x04], 'application/zip', ['.docx', '.xlsx', '.zip']),
    (0, [0x49, 0x44, 0x33], 'audio/mpeg', ['.mp3']),
    (0, [0xFF, 0xFB], 'audio/mpeg', ['.mp3']),
    (0, [0x66, 0x4C, 0x61, 0x43], 'audio/flac', ['.flac']),
    (0, [0x4F, 0x67, 0x67, 0x53], 'audio/ogg', ['.ogg', '.opus']),
    (0, [0x1A, 0x45, 0xDF, 0xA3], 'video/x-matroska', ['.mkv', '.webm']),
    (4, [0x66, 0x74, 0x79, 0x70], 'video/mp4', ['.mp4', '.m4a', '.mov']),
  ];

  static const _supportedMimes = {
    'image/jpeg', 'image/png', 'image/gif', 'image/bmp', 'image/webp',
    'image/tiff', 'image/heic', 'image/heif',
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/zip',
    'text/plain', 'text/html', 'text/csv', 'text/markdown',
    'application/json',
    'audio/mpeg', 'audio/flac', 'audio/ogg', 'audio/wav', 'audio/aac',
    'video/mp4', 'video/x-matroska', 'video/avi', 'video/quicktime',
  };

  static Future<ValidationResult> validate(String filePath) async {
    final file = File(filePath);
    final ext = filePath.toLowerCase().contains('.')
        ? '.${filePath.split('.').last.toLowerCase()}'
        : '';

    if (!await file.exists()) {
      return ValidationResult(
        status: ValidationStatus.unsupported,
        detectedMime: 'unknown',
        declaredExtension: ext,
        message: 'File not found.',
      );
    }

    final size = await file.length();
    if (size == 0) {
      return ValidationResult(
        status: ValidationStatus.empty,
        detectedMime: 'empty',
        declaredExtension: ext,
        message: 'File is empty.',
      );
    }

    final bytes = await _readHeader(file);
    final detectedMime = _detectMime(bytes, ext);

    if (!_supportedMimes.contains(detectedMime)) {
      // Text-based formats have no magic bytes — accept by extension
      if (_isTextBased(ext)) {
        return ValidationResult(
          status: ValidationStatus.ok,
          detectedMime: _mimeForTextExt(ext),
          declaredExtension: ext,
        );
      }
      return ValidationResult(
        status: ValidationStatus.unsupported,
        detectedMime: detectedMime,
        declaredExtension: ext,
        message: 'Format not supported: $detectedMime',
      );
    }

    final expectedExts = _extensionsForMime(detectedMime);
    final status = expectedExts.isEmpty || expectedExts.contains(ext)
        ? ValidationStatus.ok
        : ValidationStatus.mismatch;

    return ValidationResult(
      status: status,
      detectedMime: detectedMime,
      declaredExtension: ext,
      message: status == ValidationStatus.mismatch
          ? 'Extension $ext does not match detected type $detectedMime'
          : '',
    );
  }

  static Future<Uint8List> _readHeader(File file) async {
    final raf = await file.open();
    final bytes = await raf.read(16);
    await raf.close();
    return bytes;
  }

  static String _detectMime(Uint8List bytes, String ext) {
    for (final (offset, sig, mime, _) in _signatures) {
      if (bytes.length < offset + sig.length) continue;
      bool match = true;
      for (int i = 0; i < sig.length; i++) {
        if (bytes[offset + i] != sig[i]) { match = false; break; }
      }
      if (match) {
        // Disambiguate RIFF-based formats (WAV vs WebP vs AVI)
        if (mime == 'application/zip' && (ext == '.docx' || ext == '.xlsx')) {
          return ext == '.docx'
              ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        }
        return mime;
      }
    }
    return 'application/octet-stream';
  }

  static List<String> _extensionsForMime(String mime) {
    for (final (_, _, m, exts) in _signatures) {
      if (m == mime) return exts;
    }
    return [];
  }

  static bool _isTextBased(String ext) =>
      ['.txt', '.csv', '.json', '.yaml', '.yml', '.md', '.html', '.rtf'].contains(ext);

  static String _mimeForTextExt(String ext) => switch (ext) {
    '.csv' => 'text/csv',
    '.json' => 'application/json',
    '.yaml' || '.yml' => 'text/x-yaml',
    '.md' => 'text/markdown',
    '.html' => 'text/html',
    _ => 'text/plain',
  };
}
