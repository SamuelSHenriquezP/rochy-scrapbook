import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rochy/services/location_service.dart';
import 'package:rochy/services/map_links.dart';

Map<String, Object> feature(List<Object> coordinates) => {
      'geometry': {'type': 'Point', 'coordinates': coordinates},
      'properties': {
        'name': 'Café real',
        'street': 'Calle Baloco',
        'city': 'Cartagena',
        'country': 'Colombia'
      },
    };

void main() {
  test('coordinates and Google Maps preserve hemispheres and exact precision',
      () {
    final point = LocationService.parseCoordinates(' -33.448891, -70.669265 ');
    expect(point, isNotNull);
    final uri =
        MapLinks.googleMaps(point!.latitude, point.longitude, directions: true);
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters,
        {'api': '1', 'destination': '-33.448891,-70.669265'});
    expect(MapLinks.googleMaps(0, 0).queryParameters['query'], '0.0,0.0');
    expect(LocationService.parseCoordinates('91,0'), isNull);
    expect(LocationService.parseCoordinates('NaN,0'), isNull);
    expect(LocationService.parseCoordinates('1,181'), isNull);
    expect(() => MapLinks.googleMaps(double.infinity, 0), throwsArgumentError);
  });

  test('coordinate search needs no internet', () async {
    final service = LocationService(client: MockClient((_) async {
      fail('Decimal coordinates must be handled locally.');
    }));
    addTearDown(service.dispose);
    final results = await service.searchPlaces('10.4236,-75.5512');
    expect(results.single.latitude, 10.4236);
    expect(results.single.longitude, -75.5512);
  });

  test('Photon longitude/latitude are read correctly; bad points are skipped',
      () async {
    var calls = 0;
    final service = LocationService(client: MockClient((request) async {
      calls++;
      expect(request.url.queryParameters['q'], 'Café Cartagena');
      return http.Response(
          jsonEncode({
            'features': [
              feature([-75.5512, 10.4236]),
              feature([200, 10]),
              <String, Object>{'properties': <String, Object>{}},
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    addTearDown(service.dispose);
    final results = await service.searchPlaces('Café Cartagena');
    expect(results, hasLength(1));
    expect(results.single.shortName, 'Café real');
    expect(results.single.latitude, 10.4236);
    expect(results.single.longitude, -75.5512);
    await service.searchPlaces('Café Cartagena');
    expect(calls, 1);
  });

  test(
      'reverse geocoding keeps the selected point instead of snapping to street',
      () async {
    final service = LocationService(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'features': [
                feature([-75.55, 10.42])
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    addTearDown(service.dispose);
    final place = await service.reverseGeocode(10.423612345, -75.551234567);
    expect(place!.latitude, 10.423612345);
    expect(place.longitude, -75.551234567);
  });

  test('network failure leaves manual pins usable and does not invent a place',
      () async {
    final service = LocationService(
        client: MockClient((_) async => http.Response('unavailable', 503)));
    addTearDown(service.dispose);
    expect(await service.searchPlaces('Cartagena'), isEmpty);
    expect(await service.reverseGeocode(10.42, -75.55), isNull);
  });
}
