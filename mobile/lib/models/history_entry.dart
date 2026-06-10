import 'dart:convert';

class HistoryEntry {
  final int? id;
  final DateTime createdAt;
  final String inputName;
  final String inputFormat;
  final String outputFormat;
  final Map<String, dynamic> settings;
  final int? outputSize;
  final int? durationMs;
  final bool success;
  final String? errorMessage;

  const HistoryEntry({
    this.id,
    required this.createdAt,
    required this.inputName,
    required this.inputFormat,
    required this.outputFormat,
    required this.settings,
    this.outputSize,
    this.durationMs,
    required this.success,
    this.errorMessage,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> m) => HistoryEntry(
    id: m['id'] as int?,
    createdAt: DateTime.parse(m['created_at'] as String),
    inputName: m['input_name'] as String,
    inputFormat: m['input_format'] as String,
    outputFormat: m['output_format'] as String,
    settings: _parseJson(m['settings_json'] as String? ?? '{}'),
    outputSize: m['output_size'] as int?,
    durationMs: m['duration_ms'] as int?,
    success: (m['success'] as int) == 1,
    errorMessage: m['error_message'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'created_at': createdAt.toIso8601String(),
    'input_name': inputName,
    'input_format': inputFormat,
    'output_format': outputFormat,
    'settings_json': jsonEncode(settings),
    'output_size': outputSize,
    'duration_ms': durationMs,
    'success': success ? 1 : 0,
    'error_message': errorMessage,
  };

  static Map<String, dynamic> _parseJson(String s) {
    if (s.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return {};
    }
  }
}
