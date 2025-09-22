import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../domain/entities/participante.dart';
import '../domain/services/participante_services.dart';

class ParticipantServiceSupabase implements ParticipantService {
  final SupabaseClient _c;
  ParticipantServiceSupabase([SupabaseClient? client]) : _c = client ?? supa();

  static const _table = 'participantes';
  static const _colId = 'id';
  static const _colActivityId = 'activity_id';
  static const _colUserId = 'user_id';
  static const _colJoinedAt = 'joined_at';
  static const _colStatus = 'status';
  static const _colRole = 'role';  

 
  ParticipantRole _roleFromDb(dynamic v) {
    final s = (v ?? '').toString();
    switch (s) {
      case 'coordinador':
        return ParticipantRole.coordinador;
      case 'miembro':
      default:
        return ParticipantRole.miembro;
    }
  }

  String _roleToDb(ParticipantRole r) => switch (r) {
        ParticipantRole.coordinador => 'coordinador',
        ParticipantRole.miembro => 'miembro',
      };

  Participant _fromRow(Map<String, dynamic> m) => Participant(
        id: (m[_colId] ?? '').toString(),
        activityId: (m[_colActivityId] ?? '').toString(),
        userId: (m[_colUserId] ?? '').toString(),
        role: _roleFromDb(m[_colRole]),
        joinedAt: DateTime.parse(m[_colJoinedAt].toString()),
        status: (m[_colStatus] as String?),
      );

  @override
  Future<List<String>> activityIdsByUser(String userId) async {
    final rows =
        await _c.from(_table).select(_colActivityId).eq(_colUserId, userId);
    return List<Map<String, dynamic>>.from(rows as List)
        .map((m) => (m[_colActivityId] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Future<List<Participant>> listByActivity(String activityId) async {
    final rows = await _c
        .from(_table)
        .select('$_colId,$_colActivityId,$_colUserId,$_colJoinedAt,$_colStatus,$_colRole')
        .eq(_colActivityId, activityId);
    return List<Map<String, dynamic>>.from(rows as List)
        .map((e) => _fromRow(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<void> join(
    String activityId,
    String userId, {
    ParticipantRole role = ParticipantRole.miembro,
  }) async {
    await _c.from(_table).upsert({
      _colActivityId: activityId,
      _colUserId: userId,
      _colRole: _roleToDb(role),  
      _colStatus: 'joined',       
      _colJoinedAt: DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'activity_id,user_id');  
  }

  @override
  Future<void> leave(String activityId, String userId) async {
    await _c
        .from(_table)
        .delete()
        .match({_colActivityId: activityId, _colUserId: userId});
  }
}
