class FieldSpec {
  final String key;        // identificador único del campo
  final String type;       // "text", "number", "boolean", "select"
  final String label;      // texto a mostrar en la UI
  final bool required;     // si es obligatorio o no
  final num? min;          // para number
  final num? max;          // para number
  final List<String> options; // para select

  const FieldSpec({
    required this.key,
    required this.type,
    required this.label,
    this.required = false,
    this.min,
    this.max,
    this.options = const [],
  });

  factory FieldSpec.fromJson(Map<String, dynamic> m) => FieldSpec(
        key: (m['key'] ?? '').toString(),
        type: (m['type'] ?? 'text').toString(),
        label: (m['label'] ?? '').toString(),
        required: m['required'] == true,
        min: m['min'] is num ? m['min'] as num : null,
        max: m['max'] is num ? m['max'] as num : null,
        options: (m['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'type': type,
        'label': label,
        'required': required,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (options.isNotEmpty) 'options': options,
      };

  /// Convierte una lista dinámica en una lista de FieldSpec
  static List<FieldSpec> listFrom(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => FieldSpec.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}
