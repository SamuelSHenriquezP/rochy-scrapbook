import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rochy/services/rochy_account_service.dart';
import 'package:rochy/services/rochy_cloud_sync_service.dart';

const project = FirebaseCoupleConfig.defaultProjectId;
const storageKey = 'rochy_device_identity_$project';
String cachedIdentity() => jsonEncode({
      'uid': 'previous-device',
      'refreshToken': 'previous-refresh',
      'profileId': 'samuel',
    });
http.Response freshIdentity(String uid) => http.Response(
    jsonEncode({
      'localId': uid,
      'idToken': 'token-$uid',
      'refreshToken': 'refresh-$uid',
      'expiresIn': '3600',
    }),
    200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'invalid refresh identity can recover with a fresh device and profile code',
      () async {
    FlutterSecureStorage.setMockInitialValues({storageKey: cachedIdentity()});
    var signups = 0;
    final account = RochyAccountService(client: MockClient((request) async {
      if (request.url.host == 'securetoken.googleapis.com') {
        return http.Response('{"error":{"message":"USER_NOT_FOUND"}}', 400);
      }
      signups++;
      return freshIdentity('new-device');
    }));
    addTearDown(account.dispose);
    await account.initialize(
        projectId: project, apiKey: FirebaseCoupleConfig.defaultApiKey);
    expect(signups, 1);
    expect(account.uid, 'new-device');
    expect(account.isLinked, isFalse);
    expect(await account.idTokenFor(project), 'token-new-device');
  });

  test('temporary Firebase outage retains the linked offline identity',
      () async {
    FlutterSecureStorage.setMockInitialValues({storageKey: cachedIdentity()});
    final account = RochyAccountService(client: MockClient((request) async {
      expect(request.url.host, 'securetoken.googleapis.com');
      return http.Response('Unavailable', 503);
    }));
    addTearDown(account.dispose);
    await account.initialize(
        projectId: project, apiKey: FirebaseCoupleConfig.defaultApiKey);
    expect(account.uid, 'previous-device');
    expect(account.authorId, 'samuel');
    await expectLater(
        account.idTokenFor(project), throwsA(isA<http.ClientException>()));
    expect(await const FlutterSecureStorage().read(key: storageKey),
        cachedIdentity());
  });

  test(
      'damaged identity cache does not permanently block entering a recovery code',
      () async {
    FlutterSecureStorage.setMockInitialValues({storageKey: '{broken'});
    final account = RochyAccountService(
        client: MockClient((_) async => freshIdentity('recovered')));
    addTearDown(account.dispose);
    await account.initialize(
        projectId: project, apiKey: FirebaseCoupleConfig.defaultApiKey);
    expect(account.uid, 'recovered');
    expect(account.isLinked, isFalse);
  });

  test(
      'failed configuration change cannot reuse the token from the former project',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    var failSecondProject = true;
    final account = RochyAccountService(client: MockClient((request) async {
      if (request.url.queryParameters['key'] == 'other-key' &&
          failSecondProject) {
        return http.Response('Unavailable', 503);
      }
      return freshIdentity(request.url.queryParameters['key'] == 'other-key'
          ? 'other'
          : 'original');
    }));
    addTearDown(account.dispose);
    await account.initialize(
        projectId: project, apiKey: FirebaseCoupleConfig.defaultApiKey);
    await expectLater(
        account.initialize(projectId: 'other-project', apiKey: 'other-key'),
        throwsA(isA<http.ClientException>()));
    await expectLater(account.idTokenFor('other-project'),
        throwsA(isA<RochyAccountException>()));
    failSecondProject = false;
    await account.initialize(projectId: 'other-project', apiKey: 'other-key');
    expect(await account.idTokenFor('other-project'), 'token-other');
  });
}
