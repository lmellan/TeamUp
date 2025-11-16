class PickedPlace {
  final String placeName;
  final String formattedAddress;
  final double lat;
  final double lng;
  final String? placeId;
  final String? comunaName;  // 👈 nuevo
  final String? regionName;  // 👈 nuevo

  PickedPlace({
    required this.placeName,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.placeId,
    this.comunaName,  // 👈 nuevo
    this.regionName,  // 👈 nuevo
  });
}
