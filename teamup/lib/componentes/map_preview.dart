import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MapPreview extends StatelessWidget {
  final double lat;
  final double lng;
  final String? label;
  final String? placeId;

  const MapPreview({
    super.key,
    required this.lat,
    required this.lng,
    this.label,
    this.placeId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(lat, lng),
                zoom: 14,
              ),
             
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{}.toSet(),

              // Marcador sin InfoWindow que bloquee el botón
              markers: {
                Marker(
                  markerId: const MarkerId('activity_location'),
                  position: LatLng(lat, lng),
                  infoWindow: const InfoWindow(title: ''),
                  consumeTapEvents: false,
                ),
              },
            ),

            // Overlay invisible que captura toques en todo el mapa
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openMaps(
                  placeId: placeId,
                  lat: lat,
                  lng: lng,
                  label: label,
                ),
              ),
            ),

            // Botón flotante (ahora sí clickeable)
            Positioned(
              bottom: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openMaps(
                    placeId: placeId,
                    lat: lat,
                    lng: lng,
                    label: label,
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.map, size: 16),
                        SizedBox(width: 6),
                        Text('Abrir en Maps'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Abre Google Maps o Apple Maps según la plataforma.
  Future<void> _openMaps({
    String? placeId,
    double? lat,
    double? lng,
    String? label,
  }) async {
    Uri? uri;
    final hasCoords = lat != null && lng != null;
    final name = (label ?? 'Ubicación').trim();
    final nameEnc = Uri.encodeComponent(name);

    if (Platform.isAndroid) {
      if (hasCoords) {
        // Se comporta igual que un link de WhatsApp: abre el pin directamente
        final latStr = lat!.toStringAsFixed(6);
        final lngStr = lng!.toStringAsFixed(6);
        uri = Uri.parse('geo:0,0?q=$latStr,$lngStr($nameEnc)');
      } else if (placeId != null && placeId.trim().isNotEmpty) {
        // Fallback solo web si no hay coordenadas
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query_place_id=${Uri.encodeComponent(placeId)}'
        );
      }
    } else if (Platform.isIOS) {
      if (hasCoords) {
        final latStr = lat!.toStringAsFixed(6);
        final lngStr = lng!.toStringAsFixed(6);
        final gmaps = Uri.parse('comgooglemaps://?q=$latStr,$lngStr($nameEnc)');
        if (await canLaunchUrl(gmaps)) {
          uri = gmaps;
        } else {
          uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latStr,$lngStr');
        }
      } else if (placeId != null && placeId.trim().isNotEmpty) {
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query_place_id=${Uri.encodeComponent(placeId)}'
        );
      }
    } else {
      // Desktop / Web fallback
      if (hasCoords) {
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}'
        );
      } else if (placeId != null && placeId.trim().isNotEmpty) {
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query_place_id=${Uri.encodeComponent(placeId)}'
        );
      }
    }

    uri ??= Uri.parse('https://www.google.com/maps');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }


}
