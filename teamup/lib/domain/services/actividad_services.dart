 
import '../entities/actividad.dart';

abstract class ActivityService {
  Future<List<Activity>> list({
    DateTime? startUtc,
    DateTime? endUtc,
    List<String>? estados,
    List<String>? sportIds,
    int limit = 200,
    bool ascending = true,
  });

  Future<List<Activity>> listByIds(List<String> ids, {bool ascending = true});
  Future<Activity?> getById(String id);

  // ⬇️ Cambiar a devolver la actividad borrada (o null si no vuelve nada)
  Future<Activity?> delete(String id);

  Future<Activity> update(String id, Activity updated);

  // ⬇️ Alinear firma a la implementación (con ascending, limit y filtros opcionales)
  Future<List<Activity>> listByCoordinator(
    String coordinatorId, {
    bool ascending = true,
    int limit = 200,
    DateTime? startUtc,
    DateTime? endUtc,
    List<String>? estados,
    List<String>? sportIds,
  });
    Future<List<Activity>> listByRegionComuna({
    String? region,
    String? comuna,
    bool ascending = true,
    int limit = 200,
  });

}
