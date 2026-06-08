class ConversionJob {
  final String id;
  final String inputPath;
  final String inputName;
  final String inputFormat;
  final String outputFormat;
  final Map<String, dynamic> options;

  const ConversionJob({
    required this.id,
    required this.inputPath,
    required this.inputName,
    required this.inputFormat,
    required this.outputFormat,
    this.options = const {},
  });
}

enum JobStatus { pending, processing, success, failed }

class JobResult {
  final String jobId;
  final bool success;
  final String? outputPath;
  final int? outputSizeBytes;
  final int? durationMs;
  final String? errorCode;
  final String? errorMessage;

  const JobResult({
    required this.jobId,
    required this.success,
    this.outputPath,
    this.outputSizeBytes,
    this.durationMs,
    this.errorCode,
    this.errorMessage,
  });

  factory JobResult.succeeded({
    required String jobId,
    required String outputPath,
    required int outputSizeBytes,
    required int durationMs,
  }) => JobResult(
    jobId: jobId,
    success: true,
    outputPath: outputPath,
    outputSizeBytes: outputSizeBytes,
    durationMs: durationMs,
  );

  factory JobResult.failed({
    required String jobId,
    required String errorCode,
    required String errorMessage,
    int? durationMs,
  }) => JobResult(
    jobId: jobId,
    success: false,
    errorCode: errorCode,
    errorMessage: errorMessage,
    durationMs: durationMs,
  );
}
