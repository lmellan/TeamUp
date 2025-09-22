import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../domain/entities/actividad.dart';
import '../domain/services/actividad_services.dart';

class ActivityServiceSupabase implements ActivityService {
  final SupabaseClient _c;
  ActivityServiceSupabase([SupabaseClient? client]) : _c = client ?? supa();

  static const _table = 'actividades';
  static const _colId = 'id';
  static const _colTitle = 'title';
  static const _colDate = 'date';
  static const _colSportId = 'sport_id';
  static const _colStatus = 'status';
  static const _colPlaceName = 'place_name';
  static const _colFormattedAddress = 'formatted_address';
  static const _colDescription = 'description';
  static const _colCreatorId = 'creator_id';       
  static const _colMaxPlayers = 'max_players';      

  Activity _fromRow(Map<String, dynamic> m) => Activity(
        id: (m[_colId] ?? '').toString(),
        title: (m[_colTitle] as String?)?.trim(),
        dateUtc: DateTime.parse(m[_colDate].toString()).toUtc(),
        sportId: (m[_colSportId] ?? '').toString(),
        status: (m[_colStatus] ?? '').toString().trim().toLowerCase(),
        placeName: (m[_colPlaceName] as String?)?.trim(),
        formattedAddress: (m[_colFormattedAddress] as String?)?.trim(),
        description: (m[_colDescription] as String?)?.trim(),
        creatorId: (m[_colCreatorId] as String?)?.toString(),
        maxPlayers: m[_colMaxPlayers] as int?,
      );

  String get _selectCols =>
      '$_colId,$_colTitle,$_colDate,$_colSportId,$_colStatus,$_colPlaceName,$_colFormattedAddress,$_colDescription,$_colCreatorId,$_colMaxPlayers';

  @override
  Future<Activity?> getById(String id) async {
    final rows = await _c.from(_table).select(_selectCols).eq(_colId, id).limit(1);
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return null;
    return _fromRow(list.first);
  }

  @override
  Future<List<Activity>> list({
    DateTime? startUtc,
    DateTime? endUtc,
    List<String>? estados,
    List<String>? sportIds,
    int limit = 200,
    bool ascending = true,
  }) async {
    var q = _c.from(_table).select(_selectCols);
    if (estados != null && estados.isNotEmpty) q = q.inFilter(_colStatus, estados);
    if (startUtc != null) q = q.gte(_colDate, startUtc.toIso8601String());
    if (endUtc != null)   q = q.lt(_colDate,  endUtc.toIso8601String());
    if (sportIds != null && sportIds.isNotEmpty) q = q.inFilter(_colSportId, sportIds);
    final rows = await q.order(_colDate, ascending: ascending).limit(limit);
    return List<Map<String, dynamic>>.from(rows as List).map(_fromRow).toList();
  }

  @override
  Future<List<Activity>> listByIds(List<String> ids, {bool ascending = true}) async {
    if (ids.isEmpty) return [];
    final rows = await _c.from(_table).select(_selectCols).inFilter(_colId, ids).order(_colDate, ascending: ascending);
    return List<Map<String, dynamic>>.from(rows as List).map(_fromRow).toList();
  }
}
