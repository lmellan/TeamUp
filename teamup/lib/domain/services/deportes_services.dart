import '../entities/deportes.dart';

abstract class SportService {
  Future<List<Sport>> listAll();
  Future<List<Sport>> listByIds(List<String> ids);
}
