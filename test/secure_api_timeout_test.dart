import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rochy/services/rochy_cloud_sync_service.dart';
import 'package:rochy/services/rochy_secure_api.dart';
import 'fixtures/device_identity.dart';

class PendingConnection extends http.BaseClient {
  bool started = false;
  final pending = Completer<http.StreamedResponse>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    started = true;
    return pending.future;
  }
}

void main() {
  testWidgets('sync times out even if the HTTP connection never opens',
      (tester) async {
    final account = fixtureDevice();
    addTearDown(account.dispose);
    await tester.runAsync(() => account.initialize(
        projectId: FirebaseCoupleConfig.defaultProjectId,
        apiKey: FirebaseCoupleConfig.defaultApiKey));
    final client = PendingConnection();
    final api =
        RochySecureApi(const FirebaseCoupleConfig(), account, client: client);
    Object? failure;
    unawaited(api.read('secureCouples/test').then<void>((_) {
      fail('A pending connection must not complete successfully');
    }, onError: (Object error) {
      failure = error;
    }));
    await tester.pump();
    expect(client.started, isTrue);
    await tester.pump(const Duration(seconds: 26));
    expect(failure, isA<TimeoutException>());
  });
}
