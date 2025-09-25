 
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

  Sport _fromRow(Map<String, dynamic> m) => Sport(
        id: (m[_colId] ?? '').toString(),
        name: (m[_colName] ?? '').toString(),
        iconEmoji: (m[_colIcon] as String?)?.trim(),
        fieldsConfig: m[_colFields] as Map<String, dynamic>?,
      );

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
