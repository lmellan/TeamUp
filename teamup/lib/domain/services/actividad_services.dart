 
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
  Future<void> delete(String id);
  Future<Activity> update(String id, Activity updated);
  
}
