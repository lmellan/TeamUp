class Activity {
  final String? id;
  final String sportId;
  final String creatorId;
  final DateTime? createdAt;

  final String title;
  final String? description;
  final DateTime date;
  final int? maxPlayers;

  final String? googlePlaceId;
  final String? placeName;
  final String? formattedAddress;
  final double? lat;
  final double? lng;
  final String? activityLocation;

  final String status;
  final String? level;
  final Map<String, dynamic> fields;

  final int? regionId;   // NUEVO
  final int? comunaId;

  const Activity({
    this.id,
    required this.sportId,
    required this.creatorId,
    required this.date,
    required this.title,
    required this.status,
    this.description,
    this.maxPlayers,
    this.googlePlaceId,
    this.placeName,
    this.formattedAddress,
    this.lat,
    this.lng,
    this.activityLocation,
    this.level,
    required this.fields,
    this.createdAt,
    this.regionId,   // NUEVO
    this.comunaId,
  });
}
