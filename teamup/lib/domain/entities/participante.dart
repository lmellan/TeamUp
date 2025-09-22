 
enum ParticipantRole { coordinador, miembro }

class Participant {
  final String id;
  final String activityId;
  final String userId;
  final ParticipantRole role;   
  final String? status;         
  final DateTime joinedAt;

  const Participant({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.status,
  });
}
