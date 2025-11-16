import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../domain/entities/actividad.dart';
import '../domain/services/actividad_services.dart';

class ActivityServiceSupabase implements ActivityService {
  static const _tbl = 'actividades';

  // columnas BD  
  static const _colId = 'id';
  static const _colSportId = 'sport_id';
  static const _colCreatorId = 'creator_id';
  static const _colCreatedAt = 'created_at';
  static const _colTitle = 'title';
  static const _colDescription = 'description';
  static const _colDate = 'date';
  static const _colMaxPlayers = 'max_players';
  static const _colGooglePlaceId = 'google_place_id';
  static const _colPlaceName = 'place_name';
  static const _colFormattedAddress = 'formatted_address';
  static const _colLat = 'lat';
  static const _colLng = 'lng';
  static const _colStatus = 'status';
  static const _colActivityLocation = 'activity_location';
  static const _colLevel = 'level';
  static const _colFields = 'fields';
  static const _colRegionId = 'region_id';
  static const _colComunaId = 'comuna_id';


  // ---------- Mappers ----------
  Activity _fromRow(Map<String, dynamic> m) => Activity(
        id: (m[_colId] ?? '').toString(),
        sportId: (m[_colSportId] ?? '').toString(),
        creatorId: (m[_colCreatorId] ?? '').toString(),
        createdAt: m[_colCreatedAt] != null
            ? DateTime.parse(m[_colCreatedAt].toString()).toUtc()
            : null,
        title: (m[_colTitle] ?? '').toString(),
        description: (m[_colDescription] as String?)?.trim(),
        date: DateTime.parse(m[_colDate].toString()).toUtc(),
        maxPlayers: (m[_colMaxPlayers] as num?)?.toInt(),
        googlePlaceId: (m[_colGooglePlaceId] as String?)?.trim(),
        placeName: (m[_colPlaceName] as String?)?.trim(),
        formattedAddress: (m[_colFormattedAddress] as String?)?.trim(),
        lat: (m[_colLat] as num?)?.toDouble(),
        lng: (m[_colLng] as num?)?.toDouble(),
        status: (m[_colStatus] ?? '').toString(),
        activityLocation: (m[_colActivityLocation] as String?)?.trim(),
        level: (m[_colLevel] as String?)?.trim(),
        fields: (m[_colFields] is Map)
            ? Map<String, dynamic>.from(m[_colFields] as Map)
            : <String, dynamic>{},
        regionId: (m[_colRegionId] as num?)?.toInt(),   // NUEVO
        comunaId: (m[_colComunaId] as num?)?.toInt(),
      );

  Map<String, dynamic> _toRow(Activity a) => {
        if (a.id != null) _colId: a.id, 
        _colSportId: a.sportId,
        _colCreatorId: a.creatorId,
        _colTitle: a.title,
        _colDescription: a.description,
        _colDate: a.date.toIso8601String(),
        _colMaxPlayers: a.maxPlayers,
        _colGooglePlaceId: a.googlePlaceId,
        _colPlaceName: a.placeName,
        _colFormattedAddress: a.formattedAddress,
        _colLat: a.lat,
        _colLng: a.lng,
        _colStatus: a.status,
        _colActivityLocation: a.activityLocation,
        _colLevel: a.level,
        _colFields: a.fields,
        _colRegionId: a.regionId,   // NUEVO
        _colComunaId: a.comunaId,
        // _colCreatedAt lo setea la DB
      };

  // ---------- Implementación de la interfaz ----------

  Future<void> _notifyNewActivity(String activityId) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'notify-new-activity',
        body: {
          'activity_id': activityId,
        },
      );
    } catch (e) {
      // No rompemos la creación si falla la notificación.
      // Puedes loguear si quieres:
      // debugPrint('Error al enviar notificación de actividad: $e');
    }
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
    final client = Supabase.instance.client;

    var query = client.from(_tbl).select();

    // filtros dinámicos
    if (startUtc != null) {
      query = query.gte(_colDate, startUtc.toIso8601String());
    }
    if (endUtc != null) {
      query = query.lt(_colDate, endUtc.toIso8601String());
    }
    if (estados != null && estados.isNotEmpty) {
      // en supabase-dart puedes usar inFilter o in_
      query = query.inFilter(_colStatus, estados);
    }
    if (sportIds != null && sportIds.isNotEmpty) {
      query = query.inFilter(_colSportId, sportIds);
    }

    final rows = await query.order(_colDate, ascending: ascending).limit(limit);
    return (rows as List).map((e) => _fromRow(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Activity>> listByIds(List<String> ids, {bool ascending = true}) async {
    if (ids.isEmpty) return <Activity>[];
    final rows = await Supabase.instance.client
        .from(_tbl)
        .select()
        .inFilter(_colId, ids)
        .order(_colDate, ascending: ascending);

    return (rows as List).map((e) => _fromRow(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Activity?> getById(String id) async {
    final row = await Supabase.instance.client
        .from(_tbl)
        .select()
        .eq(_colId, id)
        .maybeSingle(); // devuelve null si no hay

    if (row == null) return null;
    return _fromRow(row);
  }

  // crear actividad  
  Future<Activity> create(Activity a, {bool notify = true}) async {
    final row = await Supabase.instance.client
        .from(_tbl)
        .insert(_toRow(a))
        .select()
        .single();

    final created = _fromRow(row);

    if (notify && created.id != null) {
      await _notifyNewActivity(created.id!);
    }

    return created;
  }

  

  @override
  Future<Activity?> delete(String id) async {
    final row = await Supabase.instance.client
        .from(_tbl)
        .delete()
        .eq(_colId, id)
        .select()
        .maybeSingle();

    return row == null ? null : _fromRow(row);
  }

  @override
  Future<Activity> update(String id, Activity updated) async {
    // se arma el payload y se evita sobreescribir columnas que no quieres tocar
    final payload = _toRow(updated)
      ..remove(_colId)
      ..remove(_colCreatorId)  
      ..remove(_colCreatedAt);

    final row = await Supabase.instance.client
        .from(_tbl)
        .update(payload)
        .eq(_colId, id)
        .select()
        .single();

    return _fromRow(row);
  }
  @override
  Future<List<Activity>> listByCoordinator(
    String coordinatorId, {
    bool ascending = true,
    int limit = 200,
    DateTime? startUtc,
    DateTime? endUtc,
    List<String>? estados,
    List<String>? sportIds,
  }) async {
    final client = Supabase.instance.client;

    var query = client.from(_tbl).select().eq(_colCreatorId, coordinatorId);

    if (startUtc != null) {
      query = query.gte(_colDate, startUtc.toIso8601String());
    }
    if (endUtc != null) {
      query = query.lt(_colDate, endUtc.toIso8601String());
    }
    if (estados != null && estados.isNotEmpty) {
      query = query.inFilter(_colStatus, estados);
    }
    if (sportIds != null && sportIds.isNotEmpty) {
      query = query.inFilter(_colSportId, sportIds);
    }

    final rows = await query.order(_colDate, ascending: ascending).limit(limit);
    return (rows as List).map((e) => _fromRow(e as Map<String, dynamic>)).toList();
  }
    @override
  Future<List<Activity>> listByRegionComuna({
    String? region,
    String? comuna,
    bool ascending = true,
    int limit = 200,
  }) async {
    final client = Supabase.instance.client;
    var query = client.from(_tbl).select();

    // Aplica filtros de texto dinámicos
    if (region != null && region.isNotEmpty) {
      query = query.ilike(_colFormattedAddress, '%$region%');
    }

    if (comuna != null && comuna.isNotEmpty) {
      query = query.ilike(_colFormattedAddress, '%$comuna%');
    }

    final rows = await query.order(_colDate, ascending: ascending).limit(limit);
    return (rows as List)
        .map((e) => _fromRow(e as Map<String, dynamic>))
        .toList();
  }


}
