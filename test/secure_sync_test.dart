import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rochy/models/bento_node.dart';
import 'package:rochy/providers/bento_canvas_provider.dart';
import 'package:rochy/services/media_and_auth_service.dart';
import 'package:rochy/services/rochy_account_service.dart';
import 'package:rochy/services/rochy_cloud_sync_service.dart';
import 'package:rochy/services/rochy_secure_api.dart';
import 'package:rochy/services/rochy_secure_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

BentoNode textNode(String text, {String id = 'note', int day = 26}) =>
    BentoNode(
        id: id,
        type: BentoNodeType.quote,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.ivory,
        linkedNodeIds: const [],
        tags: const [],
        createdAt: DateTime(2026, 11, 20),
        updatedAt: DateTime(2026, 11, day),
        payload: QuotePayload(quoteText: text, contextLabel: ''));
RochyNotebook sampleBook(String id, String owner, NotebookSharingMode mode,
        {List<BentoNode>? nodes}) =>
    RochyNotebook(
        entity: LocalBentoRepository().loadEntity().copyWith(
            id: id,
            name: 'Nuestro cuaderno',
            ownerAuthorId: owner,
            sharingMode: mode,
            coverImageUrl: '',
            updatedAt: DateTime(2026, 11, 26)),
        nodes: nodes ?? [textNode('Original')]);
Map<String, dynamic> bookData(RochyNotebook book) => {
      'ownerProfileId': book.entity.ownerAuthorId,
      'sharingMode': book.entity.sharingMode.name,
      'entity': book.entity.toJson(),
      'nodes': book.nodes.map((n) => n.toJson()).toList(),
      'deletedNodeIds': <String>[],
      'updatedAt': DateTime(2026, 11, 26)
    };

class CloudFixture {
  CloudFixture(this.role) {
    client = MockClient(handle);
    account = RochyAccountService(client: client);
    service = RochySecureSyncService(account, client: client);
    records['secureCouples/sala-5314'] = {
      'ownerProfileId': 'samuel',
      'members': {'samuel': true, 'rochy': true},
      'createdAt': DateTime(2026),
      'updatedAt': DateTime(2026)
    };
  }
  final String role;
  final records = <String, Map<String, dynamic>>{};
  final written = <String>[];
  int uploads = 0;
  late final http.Client client;
  late final RochyAccountService account;
  late final RochySecureSyncService service;
  Map<String, dynamic> document(String path, Map<String, dynamic> data) => {
        'name': 'projects/rochy-172d1/databases/(default)/documents/$path',
        'fields': data.map((k, v) => MapEntry(k, firestoreValue(v))),
        'updateTime': '2026-11-26T00:00:00Z'
      };
  Future<http.Response> handle(http.Request request) async {
    if (request.url.host == 'identitytoolkit.googleapis.com') {
      return http.Response(
          jsonEncode({
            'localId': 'device-$role',
            'idToken': 'token-$role',
            'refreshToken': 'refresh',
            'expiresIn': '3600'
          }),
          200);
    }
    if (request.url.host == 'firebasestorage.googleapis.com') {
      expect(request.headers['authorization'], 'Firebase token-$role');
      if (request.method == 'POST') {
        uploads++;
        expect(request.bodyBytes, isNotEmpty);
        return http.Response('{}', 200);
      }
      return http.Response.bytes([1, 2, 3], 200,
          headers: {'content-type': 'image/png'});
    }
    expect(request.headers['authorization'], 'Bearer token-$role');
    if (request.url.path.endsWith('/documents:commit')) {
      for (final write in (jsonDecode(request.body)['writes'] as List)) {
        if (write['delete'] != null) {
          records.remove((write['delete'] as String).split('/documents/').last);
        } else {
          final update = write['update'] as Map;
          final path = (update['name'] as String).split('/documents/').last;
          records[path] = (update['fields'] as Map).map((k, v) => MapEntry(
              '$k', firestoreDecode(Map<String, dynamic>.from(v as Map))));
        }
      }
      return http.Response('{}', 200);
    }
    final path = request.url.path.split('/documents/').last;
    if (path.startsWith('profiles/') && !path.startsWith('profiles/$role/')) {
      fail('Cross-profile private request');
    }
    if (request.method == 'GET') {
      if (path == 'profileDevices/device-$role') {
        return http.Response(
            jsonEncode(
                document(path, {'profileId': role, 'invitationId': 'seed'})),
            200);
      }
      if (records.containsKey(path)) {
        return http.Response(jsonEncode(document(path, records[path]!)), 200);
      }
      if (path.endsWith('/notebooks') || path.endsWith('/notebookDeletions')) {
        return http.Response(
            jsonEncode({
              'documents': [
                for (final entry in records.entries)
                  if (entry.key.startsWith('$path/') &&
                      !entry.key.substring(path.length + 1).contains('/'))
                    document(entry.key, entry.value)
              ]
            }),
            200);
      }
      return http.Response('{}', 404);
    }
    if (request.method == 'DELETE') {
      records.remove(path);
      written.add('DELETE:$path');
      return http.Response('{}', 200);
    }
    expect(request.method, 'PATCH');
    written.add(path);
    final fields = jsonDecode(request.body)['fields'] as Map;
    final data = fields.map((k, v) =>
        MapEntry('$k', firestoreDecode(Map<String, dynamic>.from(v as Map))));
    records[path] = data;
    return http.Response(jsonEncode(document(path, data)), 200);
  }

  Future<CloudSyncResult> sync(List<RochyNotebook> local,
          {Set<String> deleted = const {}}) =>
      service.syncCoupleWorkspace(
          config: const FirebaseCoupleConfig(),
          localNotebooks: local,
          viewerAuthor: role,
          mediaService: MediaAndAuthService(),
          localDeletedIds: deleted);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'short access codes accept groups and lowercase without changing legacy secrets',
      () {
    expect(
        RochySecureApi.normalizeAccessCode(' abcd-efgh-jk23 '), 'ABCDEFGHJK23');
    expect(RochySecureApi.displayAccessCode('ABCDEFGHJK23'), 'ABCD-EFGH-JK23');
    const legacy = 'AbCdEfGhJkLmNpQrStUvWxYz_23456789-aBcDeFgHiJ';
    expect(RochySecureApi.normalizeAccessCode(legacy), legacy);
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  test('private mode always overrides obsolete shared flag', () {
    final entity = LocalBentoRepository().loadEntity().copyWith(
        sharingMode: NotebookSharingMode.privateOnly, isCoupleShared: true);
    expect(entity.syncsToCloud, isFalse);
    expect(entity.canReadFor('rochy'), isFalse);
  });
  test(
      'private files upload automatically into own profile and never a shared document',
      () async {
    final f = CloudFixture('samuel');
    addTearDown(f.account.dispose);
    final node = textNode('').copyWith(
        type: BentoNodeType.photoHero,
        payload: const PhotoHeroPayload(
            imageUrl: 'data:image/png;base64,AQID',
            title: 'Private photo',
            dateLabel: '',
            locationLabel: '',
            storyBody: ''));
    await f.sync([
      sampleBook('secret', 'samuel', NotebookSharingMode.privateOnly,
          nodes: [node]),
      sampleBook('other', 'rochy', NotebookSharingMode.privateOnly)
    ]);
    expect(f.uploads, 1);
    expect(f.records.containsKey('profiles/samuel/notebooks/secret'), isTrue);
    expect(f.written.any((p) => p.contains('/notebooks/other')), isFalse);
    expect(f.records.containsKey('secureCouples/sala-5314/notebooks/secret'),
        isFalse);
    expect(jsonEncode(f.records['profiles/samuel/notebooks/secret']),
        contains('rochy-storage://'));
    expect(jsonEncode(f.records['profiles/samuel/notebooks/secret']),
        isNot(contains('data:image')));
  });
  test(
      'fresh default notebook cannot overwrite metadata or privatize an existing shared notebook',
      () async {
    final f = CloudFixture('samuel');
    addTearDown(f.account.dispose);
    final remote = sampleBook(
        'entity_rochy', 'samuel', NotebookSharingMode.sharedViewOnly);
    f.records['secureCouples/sala-5314/notebooks/entity_rochy'] =
        bookData(remote);
    final seed = LocalBentoRepository().loadNotebooks().first;
    final result = await f.sync([seed]);
    expect(result.mergedLocalNotebooks.single.entity.name, 'Nuestro cuaderno');
    expect(result.mergedLocalNotebooks.single.entity.sharingMode,
        NotebookSharingMode.sharedViewOnly);
    expect(f.records.containsKey('profiles/samuel/notebooks/entity_rochy'),
        isFalse);
    expect(
        f.records.containsKey('secureCouples/sala-5314/notebooks/entity_rochy'),
        isTrue);
  });
  test(
      'Rochy discards the default Sam cache and sees the actual shared notebook',
      () async {
    final f = CloudFixture('rochy');
    addTearDown(f.account.dispose);
    f.records['secureCouples/sala-5314/notebooks/entity_rochy'] = bookData(
        sampleBook(
            'entity_rochy', 'samuel', NotebookSharingMode.sharedViewOnly));
    final result = await f.sync([LocalBentoRepository().loadNotebooks().first]);
    expect(result.mergedLocalNotebooks.single.nodes, isNotEmpty);
    expect(result.mergedLocalNotebooks.single.entity.sharingMode,
        NotebookSharingMode.sharedViewOnly);
  });
  test(
      'both sides merge shared edits without replacing the owner or losing remote notes',
      () async {
    final f = CloudFixture('rochy');
    addTearDown(f.account.dispose);
    final remote = sampleBook(
        'shared', 'samuel', NotebookSharingMode.sharedEdit,
        nodes: [textNode('Original'), textNode('Other', id: 'other')]);
    f.records['secureCouples/sala-5314/notebooks/shared'] = bookData(remote);
    final result = await f.sync([
      remote.copyWith(nodes: [textNode('Changed', day: 27)])
    ]);
    expect(result.mergedLocalNotebooks.single.nodes, hasLength(2));
    expect(
        f.records['secureCouples/sala-5314/notebooks/shared']![
            'ownerProfileId'],
        'samuel');
  });
  test('view-only partner edits are discarded and never sent to Firebase',
      () async {
    final f = CloudFixture('rochy');
    addTearDown(f.account.dispose);
    final remote =
        sampleBook('view', 'samuel', NotebookSharingMode.sharedViewOnly);
    f.records['secureCouples/sala-5314/notebooks/view'] = bookData(remote);
    final result = await f.sync([
      remote.copyWith(nodes: [textNode('Unauthorized', day: 27)])
    ]);
    expect(
        (result.mergedLocalNotebooks.single.nodes.single.payload
                as QuotePayload)
            .quoteText,
        'Original');
    expect(
        f.written, isNot(contains('secureCouples/sala-5314/notebooks/view')));
  });
  test(
      'explicit private change moves the notebook and acknowledges the one-time change',
      () async {
    final f = CloudFixture('samuel');
    addTearDown(f.account.dispose);
    final remote =
        sampleBook('view', 'samuel', NotebookSharingMode.sharedViewOnly);
    f.records['secureCouples/sala-5314/notebooks/view'] = bookData(remote);
    final local = remote.copyWith(
        entity: remote.entity.copyWith(
            sharingMode: NotebookSharingMode.privateOnly,
            updatedAt: DateTime(2026, 11, 27)));
    final result =
        await f.sync([local], deleted: {'__visibility__:view:privateOnly'});
    expect(f.records.containsKey('profiles/samuel/notebooks/view'), isTrue);
    expect(f.records.containsKey('secureCouples/sala-5314/notebooks/view'),
        isFalse);
    expect(result.acknowledgedVisibilityChanges,
        contains('__visibility__:view:privateOnly'));
  });
  test('deleted notebooks stay deleted on another owner device', () async {
    final f = CloudFixture('samuel');
    addTearDown(f.account.dispose);
    final book =
        sampleBook('removed', 'samuel', NotebookSharingMode.sharedEdit);
    f.records['secureCouples/sala-5314/notebooks/removed'] = bookData(book);
    await f.sync([book], deleted: {'__book__:removed'});
    expect(
        f.records
            .containsKey('secureCouples/sala-5314/notebookDeletions/removed'),
        isTrue);
    final result = await f.sync([book]);
    expect(result.mergedLocalNotebooks, isEmpty);
    expect(f.records.containsKey('secureCouples/sala-5314/notebooks/removed'),
        isFalse);
  });
  test(
      'changing permanent code atomically replaces the old key and preserves other profile',
      () async {
    final f = CloudFixture('samuel');
    addTearDown(f.account.dispose);
    f.records['profileAccess/samuel'] = {'code': 'old-sam-code'};
    f.records['recoveryKeys/old-sam-code'] = {
      'profiles': ['samuel']
    };
    f.records['profileAccess/rochy'] = {'code': 'rochy-code'};
    final api = f.service.apiFor(const FirebaseCoupleConfig());
    final code = await api.changeAccessCode();
    expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{12}$')));
    expect(await api.accessCode(), code);
    expect(f.records.containsKey('recoveryKeys/old-sam-code'), isFalse);
    expect(f.records['recoveryKeys/$code']!['profiles'], ['samuel']);
    expect(f.records['profileAccess/rochy']!['code'], 'rochy-code');
  });
}
