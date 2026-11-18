import 'package:url_launcher/url_launcher.dart';

/// Shared validation for stored pins, geocoding results and external maps.
bool isValidMapPoint(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;

class MapLinks {
  static Uri googleMaps(double latitude, double longitude,
      {bool directions = false}) {
    if (!isValidMapPoint(latitude, longitude)) {
      throw ArgumentError('Coordenadas fuera de rango.');
    }
    final coordinates = '$latitude,$longitude';
    return Uri.https('www.google.com',
        directions ? '/maps/dir/' : '/maps/search/', <String, String>{
      'api': '1',
      if (directions) 'destination': coordinates else 'query': coordinates,
    });
  }

  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
