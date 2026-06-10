import 'dart:convert';

class Preset {
  final int? id;
  final String name;
  final bool isBuiltin;
  final String outputFormat;
  final Map<String, dynamic> options;

  const Preset({
    this.id,
    required this.name,
    required this.isBuiltin,
    required this.outputFormat,
    this.options = const {},
  });

  factory Preset.fromMap(Map<String, dynamic> m) {
    Map<String, dynamic> config = {};
    try {
      final raw = m['config_json'] as String? ?? '{}';
      config = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {}
    return Preset(
      id: m['id'] as int?,
      name: m['name'] as String,
      isBuiltin: (m['is_builtin'] as int) == 1,
      outputFormat: config['output_format'] as String? ?? '',
      options: Map<String, dynamic>.from(config['options'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'is_builtin': isBuiltin ? 1 : 0,
    'config_json': jsonEncode({'output_format': outputFormat, 'options': options}),
  };
}
