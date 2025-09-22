/// Solo define la intención; la UI no conoce Supabase.
 
abstract class AuthService {
  Future<String> signUp({
    required String email,
    required String password,
    required String name,
  });

  Future<String> signIn({
    required String email,
    required String password,
  });

  Future<void> resetPassword(String email);

  Future<void> refreshSession();

  /// Devuelve el userId actual, o null si no hay sesión
  String? currentUserId();
}
