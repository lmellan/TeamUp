import '../entities/perfil.dart';

abstract class ProfileService {
  Future<Profile?> getMyProfile();                    
  Future<void> updateMyProfile(Profile profile);       
 
}
 