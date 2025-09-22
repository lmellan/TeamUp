 
class Profile {
  final String id;                  
  final String? name;                
  final String? bio;                 
  final String? avatarUrl;           
  final String? locationLabel;       
  final bool notifyNewActivity;      
  final List<String> preferredSportIds;

  const Profile({
    required this.id,
    this.name,
    this.bio,
    this.avatarUrl,
    this.locationLabel,
    this.notifyNewActivity = true,
    this.preferredSportIds = const [],
  });

  Profile copyWith({
    String? name,
    String? bio,
    String? avatarUrl,
    String? locationLabel,
    bool? notifyNewActivity,
    List<String>? preferredSportIds,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      locationLabel: locationLabel ?? this.locationLabel,
      notifyNewActivity: notifyNewActivity ?? this.notifyNewActivity,
      preferredSportIds: preferredSportIds ?? this.preferredSportIds,
    );
  }
}
