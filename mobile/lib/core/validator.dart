import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

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
    (0, [0x49, 0x49, 0x2A, 0x00], 'image/tiff', ['.tif', '.tiff']),
    (0, [0x4D, 0x4D, 0x00, 0x2A], 'image/tiff', ['.tif', '.tiff']),
    (0, [0x25, 0x50, 0x44, 0x46], 'application/pdf', ['.pdf']),
    (0, [0x50, 0x4B, 0x03, 0x04], 'application/zip', ['.docx', '.xlsx', '.zip']),
    (0, [0x49, 0x44, 0x33], 'audio/mpeg', ['.mp3']),
    (0, [0xFF, 0xFB], 'audio/mpeg', ['.mp3']),
    (0, [0xFF, 0xF3], 'audio/mpeg', ['.mp3']),
    (0, [0xFF, 0xF2], 'audio/mpeg', ['.mp3']),
    (0, [0xFF, 0xF1], 'audio/aac', ['.aac']),
    (0, [0xFF, 0xF9], 'audio/aac', ['.aac']),
    (0, [0x66, 0x4C, 0x61, 0x43], 'audio/flac', ['.flac']),
    (0, [0x4F, 0x67, 0x67, 0x53], 'audio/ogg', ['.ogg', '.opus']),
    (0, [0x1A, 0x45, 0xDF, 0xA3], 'video/x-matroska', ['.mkv', '.webm']),
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
    final ext = p.extension(filePath).toLowerCase();

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

  static bool _hasBytes(Uint8List bytes, int offset, List<int> sig) {
    if (bytes.length < offset + sig.length) return false;
    for (int i = 0; i < sig.length; i++) {
      if (bytes[offset + i] != sig[i]) return false;
    }
    return true;
  }

  static String _detectMime(Uint8List bytes, String ext) {
    // RIFF container: bytes 8–11 identify WebP / WAV / AVI
    if (_hasBytes(bytes, 0, [0x52, 0x49, 0x46, 0x46])) {
      if (_hasBytes(bytes, 8, [0x57, 0x45, 0x42, 0x50])) return 'image/webp';
      if (_hasBytes(bytes, 8, [0x57, 0x41, 0x56, 0x45])) return 'audio/wav';
      if (_hasBytes(bytes, 8, [0x41, 0x56, 0x49, 0x20])) return 'video/avi';
      return 'application/octet-stream';
    }

    // ISO-BMFF container ("ftyp" at offset 4): brand at bytes 8–11
    // distinguishes HEIC/HEIF images from MP4/MOV video.
    if (_hasBytes(bytes, 4, [0x66, 0x74, 0x79, 0x70])) {
      const heicBrands = ['heic', 'heix', 'hevc', 'heif', 'mif1', 'msf1'];
      final brand = bytes.length >= 12
          ? String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase()
          : '';
      if (heicBrands.contains(brand)) return 'image/heic';
      if (brand.startsWith('qt')) return 'video/quicktime';
      return 'video/mp4';
    }

    for (final (offset, sig, mime, _) in _signatures) {
      if (!_hasBytes(bytes, offset, sig)) continue;
      // ZIP container: docx/xlsx are zip archives — trust the extension
      if (mime == 'application/zip' && (ext == '.docx' || ext == '.xlsx')) {
        return ext == '.docx'
            ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }
      return mime;
    }
    return 'application/octet-stream';
  }

  static List<String> _extensionsForMime(String mime) {
    switch (mime) {
      case 'image/webp':
        return ['.webp'];
      case 'audio/wav':
        return ['.wav'];
      case 'video/avi':
        return ['.avi'];
      case 'image/heic':
        return ['.heic', '.heif'];
      case 'video/quicktime':
        return ['.mov'];
      case 'video/mp4':
        return ['.mp4', '.m4a', '.m4v'];
    }
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
