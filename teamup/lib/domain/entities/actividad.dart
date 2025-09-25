class Activity {
  final String id;
  final String sportId;
  final String? creatorId;


  final String? title;
  final String status;
  final String? description;

  final DateTime dateUtc;
  final String? placeName;
  final String? formattedAddress;

  final String? level;
  final int? maxPlayers;
  final Map<String, dynamic> fields;

  const Activity({
    required this.id,
    required this.creatorId,
    required this.sportId,
    required this.title,
    required this.status,
    required this.dateUtc,
    this.description,
    this.placeName,
    this.formattedAddress,
    this.lat,
    this.lng,
    this.level,
    this.maxPlayers,
    this.fields = const {},
  });

  Map<String, dynamic> toInsertJson() => {
        'creator_id': creatorId,
        'sport_id': sportId,
        'title': title,
        'description': description,
        'status': status,
        'date_utc': dateUtc.toIso8601String(),
        'place_name': placeName,
        'formatted_address': formattedAddress,
        'lat': lat,
        'lng': lng,
        'level': level,
        'max_players': maxPlayers,
        'fields': fields,
      };

  factory Activity.fromRow(Map<String, dynamic> m) => Activity(
        id: (m['id'] ?? '').toString(),
        creatorId: (m['creator_id'] ?? '').toString(),
        sportId: (m['sport_id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        description: m['description'] as String?,
        status: (m['status'] ?? 'published').toString(),
        dateUtc: DateTime.parse(m['date_utc'].toString()),
        placeName: m['place_name'] as String?,
        formattedAddress: m['formatted_address'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        level: m['level'] as String?,
        maxPlayers: m['max_players'] as int?,
        fields: Map<String, dynamic>.from(m['fields'] ?? const {}),
      );
}
