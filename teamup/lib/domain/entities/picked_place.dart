class PickedPlace {
  final String placeName;
  final String formattedAddress;
  final double lat;
  final double lng;
  final String? placeId;

  PickedPlace({
    required this.placeName,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.placeId,
  });
}
