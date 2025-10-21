// domain/services/localidades_service.dart
import '../entities/localidades/comuna.dart';
import '../entities/localidades/region.dart';
import '../entities/localidades/preferencia_localidad.dart';

abstract class CatalogoLocalidadesService {
  Future<List<RegionCL>> listarRegiones();
  Future<List<ComunaCL>> listarComunasPorRegion(int regionId);
}

abstract class PreferredLocationsService {
  Future<List<PreferenciaLocalidad>> listar(String userId);
  Future<List<int>> listarComunasResueltas(String userId);
 
  Future<void> agregarRegion(String userId, int regionId, {int prioridad = 1});
  Future<void> agregarComuna(String userId, int regionId, int comunaId, {int prioridad = 1});
  Future<void> quitarRegion(String userId, int regionId);
  Future<void> quitarComuna(String userId, int regionId, int comunaId);
}
