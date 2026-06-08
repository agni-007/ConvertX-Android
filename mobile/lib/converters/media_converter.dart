class MediaConverter {
  static Future<void> convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    Map<String, dynamic> options,
  ) async {
    throw UnsupportedError(
      'Video/audio conversion requires FFmpeg which is not bundled in this build. '
      'Supported formats: images, PDF, documents.',
    );
  }
}
