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
  // si luego quieres traer más columnas:
  // static const _colCreatedAt = 'created_at';
  // static const _colGroupType  = 'group_type';
  // static const _colEnv        = 'environment';

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
      fieldsConfig: normalized,
      // si incluyes columnas extra en el select, puedes setearlas aquí también
      // createdAt: m[_colCreatedAt] != null ? DateTime.parse(m[_colCreatedAt].toString()).toUtc() : null,
      // groupType: m[_colGroupType] as String?,
      // environment: m[_colEnv] as String?,
    );
  }

  @override
  Future<List<Sport>> listAll() async {
    final rows = await _c
        .from(_table)
        .select('$_colId,$_colName,$_colIcon,$_colFields')
        .order(_colName);
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.map(_fromRow).toList();
  }

  @override
  Future<List<Sport>> listByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _c
        .from(_table)
        .select('$_colId,$_colName,$_colIcon,$_colFields')
        .inFilter(_colId, ids)
        .order(_colName);
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.map(_fromRow).toList();
  }
}
