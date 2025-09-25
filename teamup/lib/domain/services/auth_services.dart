 
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

  String? currentUserId();
}
