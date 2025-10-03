import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

class PlacesService {
  final FlutterGooglePlacesSdk _sdk;

  PlacesService(String apiKey) : _sdk = FlutterGooglePlacesSdk(apiKey);

  Future<Place?> getPlaceDetails(String placeId) async {
    final res = await _sdk.fetchPlace(
      placeId,
      fields: const [PlaceField.Location, PlaceField.Address, PlaceField.Name],
    );
    return res.place;
  }
}
