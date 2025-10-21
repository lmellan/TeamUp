// data/catalogo_localidades_supabase.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/localidades/region.dart';
import '../domain/entities/localidades/comuna.dart';
import '../domain/services/localidades_service.dart';
 
import '../domain/entities/localidades/preferencia_localidad.dart';
 




class CatalogoLocalidadesSupabase implements CatalogoLocalidadesService {
  final _db = Supabase.instance.client;

  @override
  Future<List<RegionCL>> listarRegiones() async {
    final rows = await _db.from('regiones').select('id, nombre').order('id');
    return (rows as List).map((r) =>
      RegionCL(id: r['id'] as int, nombre: r['nombre'] as String)
    ).toList();
  }

  @override
  Future<List<ComunaCL>> listarComunasPorRegion(int regionId) async {
    final rows = await _db
      .from('comunas')
      .select('id, region_id, nombre')
      .eq('region_id', regionId)
      .order('nombre');
    return (rows as List).map((r) => ComunaCL(
      id: r['id'] as int,
      regionId: r['region_id'] as int,
      nombre: r['nombre'] as String,
    )).toList();
  }
}


 
class PreferredLocationsServiceSupabase implements PreferredLocationsService {
  final _db = Supabase.instance.client;

  @override
  Future<List<PreferenciaLocalidad>> listar(String userId) async {
    final rows = await _db
      .from('user_preferred_locations')
      .select('user_id, region_id, comuna_id, prioridad')
      .eq('user_id', userId)
      .order('prioridad');
    return (rows as List).map((r) => PreferenciaLocalidad(
      userId: r['user_id'] as String,
      regionId: r['region_id'] as int?,
      comunaId: r['comuna_id'] as int?,
      prioridad: (r['prioridad'] as num?)?.toInt() ?? 1,
    )).toList();
  }

  @override
  Future<List<int>> listarComunasResueltas(String userId) async {
    final rows = await _db
      .from('v_user_preferred_comunas')
      .select('comuna_id')
      .eq('user_id', userId);
    return (rows as List).map((r) => r['comuna_id'] as int).toList();
  }

  @override
  Future<void> agregarRegion(String userId, int regionId, {int prioridad = 1}) async {
    await _db.from('user_preferred_locations').upsert({
      'user_id': userId,
      'region_id': regionId,
      'comuna_id': null,
      'prioridad': prioridad,
    });
  }

  @override
  Future<void> agregarComuna(String userId, int regionId, int comunaId, {int prioridad = 1}) async {
    await _db.from('user_preferred_locations').upsert({
      'user_id': userId,
      'region_id': regionId,
      'comuna_id': comunaId,
      'prioridad': prioridad,
    });
  }

  @override
  Future<void> quitarRegion(String userId, int regionId) async {
    await _db.from('user_preferred_locations')
      .delete()
      .eq('user_id', userId)
      .eq('region_id', regionId)
      .isFilter('comuna_id', null);
  }

  @override
  Future<void> quitarComuna(String userId, int regionId, int comunaId) async {
    await _db.from('user_preferred_locations')
      .delete()
      .eq('user_id', userId)
      .eq('region_id', regionId)
      .eq('comuna_id', comunaId);
  }
}
