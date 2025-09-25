class FieldSpec {
  final String key;
  final String type; // "number" | "boolean" | "select" | "text"
  final String label;
  final bool? required;
  final num? min;
  final num? max;
  final List<String>? options;

  factory FieldSpec.fromJson(Map<String, dynamic> m) {
    return FieldSpec(
      key: (m['key'] ?? '').toString(),
      type: (m['type'] ?? 'text').toString(),
      label: (m['label'] ?? '').toString(),
      required: (m['required'] as bool?) ?? false,
      min: (m['min'] as num?),
      max: (m['max'] as num?),
      options: (m['options'] as List?)
          ?.map((e) => e.toString())
          .toList(growable: false),
    );
  }

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
