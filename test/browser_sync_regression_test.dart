@TestOn('browser')
library;

import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rochy/models/bento_node.dart';
import 'package:rochy/providers/bento_canvas_provider.dart';
import 'package:rochy/services/browser_snapshot_store.dart';
import 'package:rochy/services/media_and_auth_service.dart';
import 'package:rochy/services/rochy_cloud_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('browser snapshot retains pending media larger than localStorage quota',
      () async {
    final key = 'large_snapshot_${DateTime.now().microsecondsSinceEpoch}';
    final value = 'pending-video:${List.filled(6 * 1024 * 1024, 'a').join()}';
    await writeBrowserSnapshot(key, value);
    expect(await readBrowserSnapshot(key), value);
    await writeBrowserSnapshot(key, 'portable-storage-url');
    expect(await readBrowserSnapshot(key), 'portable-storage-url');
  });

  test(
      'web sync uploads media without a local directory and returns portable URLs',
      () async {
    String? cloudPayload;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{}', 404);
      if (request.method == 'POST') {
        expect(request.bodyBytes, [1, 2, 3]);
        return http.Response('{"downloadTokens":"test-token"}', 200);
      }
      cloudPayload = jsonDecode(request.body)['fields']['payloadGzipBase64']
          ['stringValue'] as String;
      return http.Response('{}', 200);
    });
    final node = BentoNode(
        id: 'photo',
        type: BentoNodeType.photoHero,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.ivory,
        linkedNodeIds: const [],
        tags: const [],
        createdAt: DateTime(2026),
        payload: const PhotoHeroPayload(
            imageUrl: 'data:image/png;base64,AQID',
            title: 'Foto',
            dateLabel: '',
            locationLabel: '',
            storyBody: ''));
    final book = RochyNotebook(
        entity: LocalBentoRepository()
            .loadEntity()
            .copyWith(sharingMode: NotebookSharingMode.sharedEdit),
        nodes: [node]);
    final result = await RochyCloudSyncService(client: client)
        .syncCoupleWorkspace(
            config: const FirebaseCoupleConfig(coupleRoomId: 'test-room'),
            localNotebooks: [book],
            viewerAuthor: 'samuel',
            mediaService: MediaAndAuthService());
    final books = jsonDecode(utf8.decode(
        const GZipDecoder().decodeBytes(base64Decode(cloudPayload!)))) as List;
    expect(books.single['nodes'][0]['payload']['imageUrl'],
        startsWith('https://firebasestorage.googleapis.com/'));
    expect(
        (result.mergedLocalNotebooks.single.nodes.single.payload
                as PhotoHeroPayload)
            .imageUrl,
        startsWith('https://firebasestorage.googleapis.com/'));
  });
}
