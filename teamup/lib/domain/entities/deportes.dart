class Sport {
  final String id;
  final String name;
  final String? iconEmoji;
  final List<FieldSpec> fields;

  Sport({
    required this.id,
    required this.name,
    this.iconEmoji,
    this.fields = const [],
  });

  factory Sport.fromRow(Map<String, dynamic> m) => Sport(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        iconEmoji: (m['icon_emoji'] as String?)?.trim(),
        fields: FieldSpec.listFrom(m['fields_config']),
      );
}
