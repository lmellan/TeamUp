// lib/data/auth_data.dart
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient, AuthException;
import '../core/supabase_client.dart';
import '../domain/services/auth_services.dart';

class AuthServiceSupabase implements AuthService {
  final SupabaseClient _c;
  AuthServiceSupabase([SupabaseClient? client]) : _c = client ?? supa();

  @override
  Future<String> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final res = await _c.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );
      final user = res.user;
      if (user == null) throw Exception('No se pudo crear el usuario');
      return user.id;
    } on AuthException catch (e) {
      throw Exception(e.message.isNotEmpty ? e.message : 'Error de autenticación');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  @override
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _c.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = res.user;
      if (user == null) throw Exception('No se pudo iniciar sesión');
      return user.id;
    } on AuthException catch (e) {
      throw Exception(e.message.isNotEmpty ? e.message : 'Credenciales inválidas');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _c.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw Exception(e.message.isNotEmpty ? e.message : 'Error de autenticación');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  @override
  Future<void> refreshSession() async {
    try {
      await _c.auth.refreshSession();
    } catch (_) {
       
    }
  }

  @override
  String? currentUserId() => _c.auth.currentUser?.id;
}
