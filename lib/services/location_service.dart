import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'map_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

@immutable
class PlaceSearchResult {
  const PlaceSearchResult({
    required this.shortName,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.subtitle = '',
  });

  final String shortName;
  final String displayName;
  final double latitude;
  final double longitude;
  final String subtitle;
}

@immutable
class LocationFetchResult {
  const LocationFetchResult({
    this.latitude,
    this.longitude,
    this.placeName,
    this.subtitle,
    this.errorMessage,
  });

  final double? latitude;
  final double? longitude;
  final String? placeName;
  final String? subtitle;
  final String? errorMessage;

  bool get isSuccess => isValidMapPoint(latitude, longitude);
}

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(service.dispose);
  return service;
});

/// Servicio para geolocalización GPS real del dispositivo y geocodificación
/// directa/inversa mediante Photon y datos de OpenStreetMap (sin llave de API).
class LocationService {
  LocationService({http.Client? client, Uri? geocoderBaseUrl})
      : _client = client ?? http.Client(),
        _geocoderBaseUrl = geocoderBaseUrl ??
            Uri.parse(
              const String.fromEnvironment('GEOCODER_URL',
                  defaultValue: 'https://photon.komoot.io'),
            );

  final http.Client _client;
  final Uri _geocoderBaseUrl;
  final Map<String, List<PlaceSearchResult>> _cache = {};

  void dispose() => _client.close();

  static String formatCoordinates(double lat, double lng) {
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lng >= 0 ? 'E' : 'O';
    return '${lat.abs().toStringAsFixed(4)}° $ns · ${lng.abs().toStringAsFixed(4)}° $ew';
  }

  /// Solicita permisos de ubicación si hace falta y obtiene la posición GPS real.
  Future<LocationFetchResult> getCurrentLocation({
    bool resolveAddress = true,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationFetchResult(
          errorMessage: 'Activa el GPS/Ubicación del teléfono para ubicarte.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationFetchResult(
            errorMessage: 'Permiso de ubicación denegado.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationFetchResult(
          errorMessage:
              'Permiso bloqueado en ajustes. Habilita la ubicación para Rochy.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      PlaceSearchResult? place;
      if (resolveAddress) {
        place = await reverseGeocode(position.latitude, position.longitude);
      }

      return LocationFetchResult(
        latitude: position.latitude,
        longitude: position.longitude,
        placeName: place?.shortName ?? 'Mi ubicación actual',
        subtitle: place?.subtitle ??
            formatCoordinates(position.latitude, position.longitude),
      );
    } on MissingPluginException {
      return const LocationFetchResult(
        errorMessage: 'GPS no disponible en esta plataforma.',
      );
    } on TimeoutException {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return LocationFetchResult(
            latitude: last.latitude,
            longitude: last.longitude,
            placeName: 'Última ubicación conocida',
            subtitle: formatCoordinates(last.latitude, last.longitude),
          );
        }
      } catch (_) {}
      return const LocationFetchResult(
        errorMessage: 'Tiempo agotado buscando señal GPS.',
      );
    } catch (_) {
      return const LocationFetchResult(
        errorMessage: 'No se pudo obtener tu ubicación actual.',
      );
    }
  }

  /// Accept decimal latitude,longitude directly, even without a connection.
  static PlaceSearchResult? parseCoordinates(String query) {
    final parts = query.trim().split(RegExp(r'\s*[,;]\s*'));
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (!isValidMapPoint(lat, lng)) return null;
    return PlaceSearchResult(
      shortName: 'Punto por coordenadas',
      displayName: formatCoordinates(lat!, lng!),
      latitude: lat,
      longitude: lng,
      subtitle: formatCoordinates(lat, lng),
    );
  }

  Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    final trimmed = query.trim();
    final point = parseCoordinates(trimmed);
    if (point != null) return [point];
    if (trimmed.length < 2) return const [];
    final hits = await _requestPlaces('/api/', {'q': trimmed, 'limit': '6'});
    if (hits.isNotEmpty) return hits;
    if (_geocoderBaseUrl.host == 'photon.komoot.io') {
      return _requestNominatim(trimmed);
    }
    return const [];
  }

  Future<PlaceSearchResult?> reverseGeocode(double lat, double lng) async {
    if (!isValidMapPoint(lat, lng)) return null;
    final places = await _requestPlaces('/reverse', {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'limit': '1',
    });
    if (places.isEmpty) return null;
    final place = places.first;
    // Keep the user's exact pin, not the nearest address returned by the server.
    return PlaceSearchResult(
      shortName: place.shortName,
      displayName: place.displayName,
      latitude: lat,
      longitude: lng,
      subtitle: place.subtitle,
    );
  }

  Future<List<PlaceSearchResult>> _requestPlaces(
    String path,
    Map<String, String> parameters,
  ) async {
    final uri = _geocoderBaseUrl.replace(
      path: '${_geocoderBaseUrl.path.replaceFirst(RegExp(r'/$'), '')}$path',
      queryParameters: parameters,
    );
    final key = uri.toString();
    if (_cache.containsKey(key)) return _cache[key]!;
    try {
      final response = await _client.get(
        uri,
        headers: const <String, String>{
          'User-Agent': 'RochyScrapbook/1.0 (contact@rochy.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final results = <PlaceSearchResult>[];
      for (final feature in (decoded['features'] as List)) {
        try {
          final coords = feature['geometry']['coordinates'] as List;
          final lng = (coords[0] as num).toDouble();
          final lat = (coords[1] as num).toDouble();
          if (!isValidMapPoint(lat, lng)) continue;
          final props = Map<String, dynamic>.from(feature['properties'] as Map);
          final name = (props['name'] as String?)?.trim();
          final shortName = name != null && name.isNotEmpty
              ? name
              : _extractShortName(props, 'Lugar marcado');
          final address = [
            props['street'],
            props['housenumber'],
            props['city'],
            props['state'],
            props['country']
          ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
          results.add(PlaceSearchResult(
            shortName: shortName,
            displayName: '$shortName, $address',
            latitude: lat,
            longitude: lng,
            subtitle: address,
          ));
        } catch (_) {
          // Ignore malformed entries; never place them at the fake point 0,0.
        }
      }
      if (_cache.length >= 64) _cache.remove(_cache.keys.first);
      _cache[key] = results;
      return results;
    } catch (_) {
      return const [];
    }
  }

  String _extractShortName(Map<String, dynamic> addr, String fallbackDisplay) {
    for (final key in const <String>[
      'amenity',
      'tourism',
      'shop',
      'leisure',
      'road',
      'neighbourhood',
      'suburb',
      'city',
      'town',
      'village',
    ]) {
      final v = (addr[key] as String?)?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final first = fallbackDisplay.split(',').first.trim();
    return first.isEmpty ? 'Lugar marcado' : first;
  }

  Future<List<PlaceSearchResult>> _requestNominatim(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '6',
    });
    final key = uri.toString();
    if (_cache.containsKey(key)) return _cache[key]!;
    try {
      final response = await _client.get(
        uri,
        headers: const <String, String>{
          'User-Agent': 'RochyScrapbook/1.0 (contact@rochy.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return const [];
      final results = <PlaceSearchResult>[];
      for (final raw in decoded) {
        if (raw is! Map) continue;
        final lat = double.tryParse('${raw['lat']}');
        final lng = double.tryParse('${raw['lon']}');
        if (!isValidMapPoint(lat, lng)) continue;
        final display = (raw['display_name'] as String?)?.trim() ?? '';
        final rawName = (raw['name'] as String?)?.trim();
        final shortName = rawName != null && rawName.isNotEmpty
            ? rawName
            : (display.split(',').first.trim().isNotEmpty
                ? display.split(',').first.trim()
                : 'Lugar marcado');
        final addrMap = raw['address'] is Map
            ? Map<String, dynamic>.from(raw['address'] as Map)
            : const <String, dynamic>{};
        final subtitle = [
          addrMap['road'],
          addrMap['suburb'] ?? addrMap['neighbourhood'],
          addrMap['city'] ?? addrMap['town'] ?? addrMap['village'],
          addrMap['country'],
        ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
        results.add(PlaceSearchResult(
          shortName: shortName,
          displayName: display.isNotEmpty ? display : shortName,
          latitude: lat!,
          longitude: lng!,
          subtitle: subtitle.isNotEmpty ? subtitle : display,
        ));
      }
      if (_cache.length >= 64) _cache.remove(_cache.keys.first);
      _cache[key] = results;
      return results;
    } catch (_) {
      return const [];
    }
  }
}
