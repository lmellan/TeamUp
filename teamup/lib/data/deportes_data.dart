// sport_service_supabase.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../domain/entities/deportes.dart';
import '../../domain/services/deportes_services.dart';

class SportServiceSupabase implements SportService {
  final SupabaseClient _c;
  SportServiceSupabase([SupabaseClient? client]) : _c = client ?? supa();

  static const _table = 'deportes';
  static const _colId = 'id';
  static const _colName = 'name';
  static const _colIcon = 'icon_emoji';
  static const _colFields = 'fields_config';
  static const _colImagePath = 'image_path';

  /// Nombre del bucket donde subiste las imágenes
  static const _bucketDeportes = 'deportes';

  Sport _fromRow(Map<String, dynamic> m) {
    final raw = m[_colFields];
    Map<String, dynamic>? normalized;
    if (raw is Map<String, dynamic>) {
      normalized = Map<String, dynamic>.from(raw);
    } else if (raw is List) {
      normalized = {'fields': raw};
    }

    return Sport(
      id: (m[_colId] ?? '').toString(),
      name: (m[_colName] ?? '').toString(),
      iconEmoji: (m[_colIcon] as String?)?.trim(),
      imagePath: (m[_colImagePath] as String?)?.trim(),
      fieldsConfig: normalized,
    );
  }

  @override
  Future<List<Sport>> listAll() async {
    final rows = await _c
        .from(_table)
        .select('$_colId,$_colName,$_colIcon,$_colFields,$_colImagePath')
        .order(_colName);
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.map(_fromRow).toList();
  }

  @override
  Future<List<Sport>> listByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _c
        .from(_table)
        .select('$_colId,$_colName,$_colIcon,$_colFields,$_colImagePath')
        .inFilter(_colId, ids)
        .order(_colName);
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.map(_fromRow).toList();
  }

  /// Devuelve la URL pública (si el bucket es público) para mostrar en Image.network
  String? publicUrlFor(Sport s) {
    final path = s.imagePath;
    if (path == null || path.isEmpty) return null;

    // Acepta tanto "futbol.jpg" como "deportes/futbol.jpg"
    final clean = path.startsWith('deportes/')
        ? path.replaceFirst('deportes/', '')
        : path;

    return _c.storage.from(_bucketDeportes).getPublicUrl(clean);
  }

  /// (opcional) URL firmada si el bucket es privado
  Future<String?> signedUrlFor(Sport s, {Duration ttl = const Duration(hours: 6)}) async {
    final path = s.imagePath;
    if (path == null || path.isEmpty) return null;

    final clean = path.startsWith('deportes/')
        ? path.replaceFirst('deportes/', '')
        : path;

    final res = await _c.storage
        .from(_bucketDeportes)
        .createSignedUrl(clean, ttl.inSeconds);
    return res;
  }

  /// (opcional) Actualiza el image_path de un deporte
  Future<void> setImagePathByName({
    required String sportName,
    required String imagePath, // ej: "futbol.jpg"
  }) async {
    await _c
        .from(_table)
        .update({_colImagePath: imagePath})
        .ilike(_colName, sportName);
  }
}
