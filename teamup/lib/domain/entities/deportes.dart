// sport.dart
import 'field_spec.dart';

class Sport {
  final String id;
  final String name;
  final String? iconEmoji;

  // columnas extra (opcionales) de la tabla `deportes`
  final DateTime? createdAt;
  final String? groupType;     // sport_group_type
  final String? environment;   // sport_environment

  /// Ruta almacenada en BD (ej: "futbol.jpg" o "deportes/futbol.jpg")
  final String? imagePath;

  /// jsonb crudo de la BD
  final Map<String, dynamic>? fieldsConfig;

  /// Campos ya parseados para la UI (a partir de fieldsConfig)
  final List<FieldSpec> fields;

  Sport({
    required this.id,
    required this.name,
    this.iconEmoji,
    this.createdAt,
    this.groupType,
    this.environment,
    this.imagePath,
    this.fieldsConfig,
    List<FieldSpec>? fields,
  }) : fields = fields ??
            FieldSpec.listFrom(
              (fieldsConfig is Map<String, dynamic>)
                  ? (fieldsConfig!['fields'] ?? [])
                  : (fieldsConfig ?? []),
            );

  factory Sport.fromJson(Map<String, dynamic> m) {
    final raw = m['fields_config'];
    Map<String, dynamic>? normalized;
    if (raw is Map<String, dynamic>) {
      normalized = raw;
    } else if (raw is List) {
      normalized = {'fields': raw};
    }

    return Sport(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      iconEmoji: (m['icon_emoji'] as String?)?.trim(),
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'].toString()).toUtc()
          : null,
      groupType: m['group_type'] as String?,
      environment: m['environment'] as String?,
      imagePath: (m['image_path'] as String?)?.trim(),
      fieldsConfig: normalized,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (iconEmoji != null) 'icon_emoji': iconEmoji,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (groupType != null) 'group_type': groupType,
        if (environment != null) 'environment': environment,
        if (imagePath != null) 'image_path': imagePath,
        if (fieldsConfig != null) 'fields_config': fieldsConfig,
      };
}
