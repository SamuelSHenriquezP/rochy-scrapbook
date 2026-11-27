import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rochy/services/rochy_account_service.dart';

RochyAccountService fixtureDevice({bool linked = true}) {
  FlutterSecureStorage.setMockInitialValues({});
  return RochyAccountService(client: MockClient((request) async {
    if (request.url.host == 'identitytoolkit.googleapis.com') {
      return http.Response(
          jsonEncode({
            'localId': 'fixture-device',
            'idToken': 'fixture-token',
            'refreshToken': 'fixture-refresh',
            'expiresIn': '3600',
          }),
          200);
    }
    if (linked && request.url.path.endsWith('/profileDevices/fixture-device')) {
      return http.Response(
          jsonEncode({
            'name':
                'projects/rochy-172d1/databases/(default)/documents/profileDevices/fixture-device',
            'fields': {
              'profileId': {'stringValue': 'samuel'},
              'invitationId': {'stringValue': 'fixture'}
            },
            'updateTime': '2026-11-27T00:00:00Z',
          }),
          200);
    }
    return http.Response('{}', 404);
  }));
}
