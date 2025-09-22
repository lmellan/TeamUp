import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/services/perfil_services.dart';

class ProfileServiceSupabase implements ProfileService {
  final SupabaseClient _c;
  ProfileServiceSupabase([SupabaseClient? client]) : _c = client ?? supa();

  Profile _fromRow(String uid, Map<String, dynamic> m) => Profile(
        id: uid,
        name: (m['name'] as String?)?.trim(),
        bio: (m['descripcion'] as String?)?.trim(),
        avatarUrl: (m['foto'] as String?)?.trim(),
        locationLabel: (m['location'] as String?)?.trim(),
        notifyNewActivity: (m['notify_new_activity'] as bool?) ?? true,
        preferredSportIds: ((m['preferred_sport_ids'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> _toRow(Profile p) => {
        'name': (p.name?.trim().isEmpty ?? true) ? null : p.name!.trim(),
        'descripcion': (p.bio?.trim().isEmpty ?? true) ? null : p.bio!.trim(),
        'foto': (p.avatarUrl?.trim().isEmpty ?? true) ? null : p.avatarUrl!.trim(),
        'location': (p.locationLabel?.trim().isEmpty ?? true) ? null : p.locationLabel!.trim(),
        'notify_new_activity': p.notifyNewActivity,
        'preferred_sport_ids': p.preferredSportIds,
        'updated_at': DateTime.now().toIso8601String(),
      };

  @override
  Future<Profile?> getMyProfile() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await _c.from('perfil').select('''
      name, descripcion, foto, location,
      preferred_sport_ids, notify_new_activity
    ''').eq('id', uid).maybeSingle();

    if (row == null) return null;
    return _fromRow(uid, Map<String, dynamic>.from(row));
  }

  @override
  Future<void> updateMyProfile(Profile p) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('No hay sesión activa');

    await _c.from('perfil').upsert({
      'id': uid,
      ..._toRow(p),
    });
  }
}
