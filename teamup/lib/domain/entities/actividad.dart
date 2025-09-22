class Activity {
  final String id;
  final DateTime dateUtc;    
  final String sportId;
  final String status;
 
  final String? title;
  final String? description;
  final String? placeName;
  final String? formattedAddress;

  const Activity({
    required this.id,
    required this.dateUtc,
    required this.sportId,
    required this.status,
    this.title,
    this.description,
    this.placeName,
    this.formattedAddress,
  });
}
