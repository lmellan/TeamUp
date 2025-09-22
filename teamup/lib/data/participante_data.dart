import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../domain/services/participante_services.dart';

class ParticipantServiceSupabase implements ParticipantService {
  final SupabaseClient _c;
  ParticipantServiceSupabase([SupabaseClient? client]) : _c = client ?? supa();

  @override
  Future<List<String>> activityIdsByUser(String userId) async {
    final rows = await _c
        .from('participantes')
        .select('activity_id')
        .eq('user_id', userId);
    return (rows as List)
        .map((e) => e['activity_id'])
        .where((v) => v != null)
        .map((v) => v.toString())
        .toList();
  }
}
