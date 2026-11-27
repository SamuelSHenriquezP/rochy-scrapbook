import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rochy/views/bento_scrapbook_view.dart';
import 'package:rochy/widgets/bento_interaction_lock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rochy/models/bento_node.dart';
import 'package:rochy/providers/bento_canvas_provider.dart';
import 'package:rochy/services/media_and_auth_service.dart';
import 'package:rochy/services/rochy_cloud_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

BentoNode note(String id, String text) => BentoNode(
      id: id,
      type: BentoNodeType.quote,
      colSpan: 1,
      rowSpan: 2,
      colorTheme: BentoColorTheme.ivory,
      linkedNodeIds: const [],
      tags: const [],
      createdAt: DateTime(2025),
      updatedAt: DateTime(2026),
      payload: QuotePayload(quoteText: text, contextLabel: 'Notas sobre ella'),
    );

class TestMedia extends MediaAndAuthService {
  TestMedia(this.dir);
  final Directory dir;
  @override
  Future<Directory> ensureMediaDir() async => dir;
}

class DeferredSync extends RochyCloudSyncService {
  final completion = Completer<CloudSyncResult>();
  @override
  Future<CloudSyncResult> syncCoupleWorkspace({
    required FirebaseCoupleConfig config,
    required List<RochyNotebook> localNotebooks,
    required String viewerAuthor,
    required MediaAndAuthService mediaService,
    Set<String> localDeletedIds = const {},
    String partnerAAvatarUrl = '',
    String partnerBAvatarUrl = '',
  }) =>
      completion.future;
}

class RetrySync extends RochyCloudSyncService {
  int calls = 0;
  @override
  Future<CloudSyncResult> syncCoupleWorkspace({
    required FirebaseCoupleConfig config,
    required List<RochyNotebook> localNotebooks,
    required String viewerAuthor,
    required MediaAndAuthService mediaService,
    Set<String> localDeletedIds = const {},
    String partnerAAvatarUrl = '',
    String partnerBAvatarUrl = '',
  }) async {
    calls++;
    if (calls == 1) {
      throw const FirebaseSyncException('Upload temporarily unavailable');
    }
    return CloudSyncResult(
        mergedLocalNotebooks: localNotebooks,
        addedNodes: 0,
        updatedNodes: 0,
        uploadedMedia: 1,
        downloadedMedia: 0);
  }
}

RochyNotebook photoBook(String source) => RochyNotebook(
      entity: LocalBentoRepository()
          .loadEntity()
          .copyWith(sharingMode: NotebookSharingMode.sharedEdit),
      nodes: [
        note('photo', '').copyWith(
            type: BentoNodeType.photoHero,
            payload: PhotoHeroPayload(
                imageUrl: source,
                title: 'Foto',
                dateLabel: '',
                locationLabel: '',
                storyBody: ''))
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'view-only blocks writes, deletion, resize, template and privacy changes',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bentoCanvasProvider.notifier);
    notifier.createNotebook(
        name: 'Vista',
        subtitle: '',
        sharingMode: NotebookSharingMode.sharedViewOnly);
    notifier.addNode(note('mine', 'Mi recuerdo'));
    final original = container.read(bentoCanvasProvider).activeNotebook;
    notifier.setViewerAuthor('rochy');
    expect(
        container.read(bentoCanvasProvider).isActiveNotebookReadOnly, isTrue);
    notifier.toggleEditMode();
    notifier.activateWidget('mine');
    notifier.addNode(note('extra', 'No guardar'));
    notifier.updateNode(note('mine', 'No reemplazar'));
    notifier.resizeNode('mine', colSpan: 2);
    expect(notifier.deleteNode('mine'), isNull);
    notifier.clearCanvas();
    notifier.restoreStarterTemplate();
    notifier.setNotebookSharingMode(
        original.entity.id, NotebookSharingMode.sharedEdit);
    notifier.deleteNotebook(original.entity.id);
    final state = container.read(bentoCanvasProvider);
    expect(state.activeNotebook.toJson(), original.toJson());
    expect(state.deletedNodeIds, isEmpty);
    expect(state.isEditMode, isFalse);
    expect(state.activeWidgetId, isNull);
  });

  testWidgets(
      'view-only keeps add and edit controls hidden after scrolling and holding',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final container = ProviderContainer();
    final notifier = container.read(bentoCanvasProvider.notifier);
    notifier
        .updateCloudConfig(const FirebaseCoupleConfig(autoSyncEnabled: false));
    notifier.createNotebook(
        name: 'Vista',
        subtitle: '',
        sharingMode: NotebookSharingMode.sharedViewOnly);
    for (var i = 0; i < 12; i++) {
      notifier.addNode(note('mine_$i', 'Recuerdo $i'));
    }
    notifier.setViewerAuthor('rochy');
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BentoScrapbookView())));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Añadir módulo'), findsNothing);
    expect(find.text('Añadir otro módulo'), findsNothing);
    expect(find.byType(ExclusiveBentoDraggable<String>), findsNothing);
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -1600));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Añadir otro módulo'), findsNothing);
    notifier.toggleNodeFocus('mine_0');
    await tester.pump();
    expect(find.text('Editar'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  test('sync cannot overwrite edits and deletions made while it is running',
      () async {
    final service = DeferredSync();
    final container = ProviderContainer(
        overrides: [rochyCloudSyncServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    final notifier = container.read(bentoCanvasProvider.notifier);
    notifier
        .updateCloudConfig(const FirebaseCoupleConfig(autoSyncEnabled: false));
    notifier.createNotebook(
        name: 'Compartido',
        subtitle: '',
        sharingMode: NotebookSharingMode.sharedEdit);
    notifier.addNode(note('old', 'Original'));
    final before = container.read(bentoCanvasProvider).notebooks;
    final syncing = notifier.syncNowWithFirebase();
    notifier.deleteNode('old');
    notifier.addNode(note('new', 'Mientras sincronizaba'));
    service.completion.complete(CloudSyncResult(
        mergedLocalNotebooks: before,
        addedNodes: 0,
        updatedNodes: 0,
        uploadedMedia: 0,
        downloadedMedia: 0));
    await syncing;
    final state = container.read(bentoCanvasProvider);
    expect(state.nodes.map((n) => n.id), ['new']);
    expect(state.deletedNodeIds, contains('old'));
  });

  test('clearing canvas records deletions so sync cannot resurrect modules',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bentoCanvasProvider.notifier);
    notifier.createNotebook(
        name: 'Compartido',
        subtitle: '',
        sharingMode: NotebookSharingMode.sharedEdit);
    notifier.addNode(note('mine', 'Mi recuerdo'));
    final remote = container.read(bentoCanvasProvider).activeNotebook;
    notifier.clearCanvas();
    final state = container.read(bentoCanvasProvider);
    final merged = RochyCloudSyncService.mergeNotebooksPure(
        localNotebooks: [state.activeNotebook],
        incomingNotebooks: [remote],
        deletedIds: state.deletedNodeIds);
    expect(merged.notebooks.single.nodes, isEmpty);
    expect(state.deletedNodeIds, contains('mine'));
  });

  test('timestamped shipped examples are removed, customized text survives',
      () {
    final demo = note('starter_quote_her',
        'Con ella hasta el silencio se siente como compañía.');
    expect(RochyCloudSyncService.isUnmodifiedDemoNode(demo), isTrue);
    expect(
        RochyCloudSyncService.isUnmodifiedDemoNode(
            note('starter_quote_her', 'Mi frase personal')),
        isFalse);
    expect(
        RochyCloudSyncService.isUnmodifiedDemoNode(note(
            'mine', 'Con ella hasta el silencio se siente como compañía.')),
        isFalse);
  });

  test('view-only merge discards unauthorized local cards and edits', () {
    final entity = LocalBentoRepository().loadEntity().copyWith(
        sharingMode: NotebookSharingMode.sharedViewOnly,
        isCoupleShared: true,
        ownerAuthorId: 'samuel');
    final remote =
        RochyNotebook(entity: entity, nodes: [note('mine', 'Original')]);
    final local = remote.copyWith(
        nodes: [note('mine', 'Cambio local'), note('extra', 'Extra')]);
    final merged = RochyCloudSyncService.mergeNotebooksPure(
        localNotebooks: [local],
        incomingNotebooks: [remote],
        localOwner: 'rochy');
    expect(merged.notebooks.single.toJson(), remote.toJson());
  });

  test(
      'missing device file is pending, never exported as a phone path or reported uploaded',
      () async {
    final dir = await Directory.systemTemp.createTemp('rochy_pending_test');
    addTearDown(() => dir.delete(recursive: true));
    String? encoded;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{}', 404);
      expect(request.method, 'PATCH');
      encoded = jsonDecode(request.body)['fields']['payloadGzipBase64']
          ['stringValue'] as String;
      return http.Response('{}', 200);
    });
    final result = await RochyCloudSyncService(client: client)
        .syncCoupleWorkspace(
            config: const FirebaseCoupleConfig(coupleRoomId: 'test-room'),
            localNotebooks: [photoBook('/old/device/rochy_media/missing.png')],
            viewerAuthor: 'samuel',
            mediaService: TestMedia(dir));
    expect(result.pendingMedia, 1);
    expect(result.uploadedMedia, 0);
    final payload =
        utf8.decode(const GZipDecoder().decodeBytes(base64Decode(encoded!)));
    expect(payload, isNot(contains('/old/device/')));
    expect(payload, contains('rochy-pending-media:missing.png'));
  });

  test(
      'original device automatically recovers and uploads a file from an old sandbox path',
      () async {
    final dir = await Directory.systemTemp.createTemp('rochy_recover_test');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}${Platform.pathSeparator}saved.png')
        .writeAsBytes([1, 2, 3]);
    var uploads = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{}', 404);
      if (request.method == 'POST') {
        uploads++;
        expect(request.bodyBytes, [1, 2, 3]);
        return http.Response('{"downloadTokens":"recovered"}', 200);
      }
      return http.Response('{}', 200);
    });
    final result = await RochyCloudSyncService(client: client)
        .syncCoupleWorkspace(
            config: const FirebaseCoupleConfig(coupleRoomId: 'test-room'),
            localNotebooks: [photoBook('/old/device/rochy_media/saved.png')],
            viewerAuthor: 'samuel',
            mediaService: TestMedia(dir));
    expect(uploads, 1);
    expect(result.uploadedMedia, 1);
    expect(result.pendingMedia, 0);
  });

  testWidgets(
      'automatic sync retries a failed upload without pressing a sync button',
      (tester) async {
    final service = RetrySync();
    final container = ProviderContainer(
        overrides: [rochyCloudSyncServiceProvider.overrideWithValue(service)]);
    final notifier = container.read(bentoCanvasProvider.notifier);
    notifier
        .updateCloudConfig(const FirebaseCoupleConfig(autoSyncEnabled: true));
    notifier.createNotebook(
        name: 'Compartido',
        subtitle: '',
        sharingMode: NotebookSharingMode.sharedEdit);
    notifier.addNode(note('automatic', 'Subida pendiente'));
    await tester.pump(const Duration(seconds: 3));
    expect(service.calls, 1);
    expect(container.read(bentoCanvasProvider).lastCloudSyncError, isNotNull);
    await tester.pump(const Duration(seconds: 25));
    expect(service.calls, 2);
    expect(container.read(bentoCanvasProvider).lastCloudSyncError, isNull);
    container.dispose();
  });

  test('sync preserves metadata written by the newer published version',
      () async {
    final dir = await Directory.systemTemp.createTemp('rochy_metadata_test');
    addTearDown(() => dir.delete(recursive: true));
    String encode(Object value) => base64Encode(
        const GZipEncoder().encode(utf8.encode(jsonEncode(value))));
    final originalMeta = <String, dynamic>{
      'partnerAName': 'Sam',
      'partnerBName': 'Rochy',
      'continuityCodeSamuel': 'keep-sam',
      'continuityCodeRochy': 'keep-rochy',
      'deletedNodeIds': <String>[],
      'partnerAAvatarUrl': '',
      'partnerBAvatarUrl': ''
    };
    Map<String, dynamic>? patched;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
            jsonEncode({
              'fields': {
                'payloadGzipBase64': {'stringValue': encode([])},
                'coupleMetaGzipBase64': {'stringValue': encode(originalMeta)},
                'privateVaultSamuelGzipBase64': {'stringValue': 'untouched'},
              }
            }),
            200);
      }
      expect(request.method, 'PATCH');
      expect(request.url.queryParametersAll['updateMask.fieldPaths'],
          isNot(contains('privateVaultSamuelGzipBase64')));
      patched = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    });
    await RochyCloudSyncService(client: client).syncCoupleWorkspace(
        config: const FirebaseCoupleConfig(coupleRoomId: 'test-room'),
        localNotebooks: [],
        viewerAuthor: 'samuel',
        mediaService: TestMedia(dir),
        localDeletedIds: {'removed'});
    final encoded =
        patched!['fields']['coupleMetaGzipBase64']['stringValue'] as String;
    final actual = jsonDecode(
            utf8.decode(const GZipDecoder().decodeBytes(base64Decode(encoded))))
        as Map;
    for (final key in [
      'partnerAName',
      'partnerBName',
      'continuityCodeSamuel',
      'continuityCodeRochy'
    ]) {
      expect(actual[key], originalMeta[key]);
    }
    expect(actual['deletedNodeIds'], ['removed']);
    expect(patched!['fields'], isNot(contains('privateVaultSamuelGzipBase64')));
  });

  test(
      'inline web media is uploaded and payload contains a portable Storage URL',
      () async {
    final dir = await Directory.systemTemp.createTemp('rochy_sync_test');
    addTearDown(() => dir.delete(recursive: true));
    Map<String, dynamic>? patched;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{}', 404);
      if (request.method == 'POST') {
        expect(request.headers['content-type'], 'image/png');
        expect(request.bodyBytes, [1, 2, 3]);
        return http.Response('{"downloadTokens":"test-token"}', 200);
      }
      patched = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    });
    final entity = LocalBentoRepository()
        .loadEntity()
        .copyWith(sharingMode: NotebookSharingMode.sharedEdit);
    final photo = note('photo', '').copyWith(
        type: BentoNodeType.photoHero,
        payload: const PhotoHeroPayload(
            imageUrl: 'data:image/png;base64,AQID',
            title: 'Foto',
            dateLabel: '',
            locationLabel: '',
            storyBody: ''));
    await RochyCloudSyncService(client: client).syncCoupleWorkspace(
        config: const FirebaseCoupleConfig(coupleRoomId: 'test-room'),
        localNotebooks: [
          RochyNotebook(entity: entity, nodes: [photo])
        ],
        viewerAuthor: 'samuel',
        mediaService: TestMedia(dir));
    final encoded = (patched!['fields'] as Map)['payloadGzipBase64']
        ['stringValue'] as String;
    final books = jsonDecode(
            utf8.decode(const GZipDecoder().decodeBytes(base64Decode(encoded))))
        as List;
    final source = books.single['nodes'][0]['payload']['imageUrl'] as String;
    expect(source, startsWith('https://firebasestorage.googleapis.com/'));
    expect(source, contains('couples%2Ftest-room%2Fmedia'));
    expect(source, contains('token=test-token'));
  });
}
