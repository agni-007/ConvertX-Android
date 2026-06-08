import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';

class MediaConverter {
  static Future<void> convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    Map<String, dynamic> options,
  ) async {
    final args = _buildArgs(inputPath, outputPath, outputFormat, options);
    final session = await FFmpegKit.execute(args);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getLogsAsString();
      throw Exception('FFmpeg failed (rc=$returnCode): $logs');
    }
  }

  static String _buildArgs(
    String input,
    String output,
    String fmt,
    Map<String, dynamic> options,
  ) {
    final args = StringBuffer('-i "$input" -y ');

    switch (fmt) {
      case 'mp4':
      case 'mkv':
      case 'webm':
      case 'avi':
      case 'mov':
        final codec = options['codec'] as String? ?? 'libx264';
        final crf = _resolveCrf(options);
        final audioMode = options['audio'] as String? ?? 'copy';
        args.write('-vcodec $codec -crf $crf -preset medium ');
        if (audioMode == 'strip') {
          args.write('-an ');
        } else if (audioMode == 'reencode') {
          args.write('-acodec aac -b:a 128k ');
        } else {
          args.write('-acodec copy ');
        }
      case 'mp3':
        final bitrate = options['audio_bitrate'] as String? ?? '128k';
        args.write('-vn -acodec libmp3lame -b:a $bitrate ');
      case 'aac':
        final bitrate = options['audio_bitrate'] as String? ?? '128k';
        args.write('-vn -acodec aac -b:a $bitrate ');
      case 'flac':
        args.write('-vn -acodec flac ');
      case 'wav':
        args.write('-vn -acodec pcm_s16le ');
      case 'ogg':
        final bitrate = options['audio_bitrate'] as String? ?? '128k';
        args.write('-vn -acodec libvorbis -b:a $bitrate ');
    }

    args.write('"$output"');
    return args.toString();
  }

  static int _resolveCrf(Map<String, dynamic> options) {
    final preset = options['quality_preset'] as String? ?? 'balanced';
    return switch (preset) {
      'quality' => 23,
      'small' => 32,
      _ => 28,
    };
  }
}
