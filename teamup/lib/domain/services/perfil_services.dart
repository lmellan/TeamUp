import '../entities/perfil.dart';

abstract class ProfileService {
  Future<Profile?> getMyProfile();                    
  Future<void> updateMyProfile(Profile profile);    
  Future<Profile?> getById(String id);                      
  Future<List<Profile>> listByIds(List<String> ids);

  Future<void> signOut() async {}      
 
}
 