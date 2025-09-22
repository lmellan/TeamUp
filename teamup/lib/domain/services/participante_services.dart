import 'package:teamup/domain/entities/participante.dart';

abstract class ParticipantService {
  Future<List<String>> activityIdsByUser(String userId);
  Future<List<Participant>> listByActivity(String activityId);
 
  Future<void> join(
    String activityId,
    String userId, {
    ParticipantRole role = ParticipantRole.miembro,
  });

  Future<void> leave(String activityId, String userId);
}
