import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/bento_node.dart';
import 'media_and_auth_service.dart';
import 'rochy_account_service.dart';
import 'rochy_cloud_sync_service.dart';
import 'rochy_secure_api.dart';
import 'rochy_secure_media_session.dart';

/// A document per notebook lets Firebase enforce private and view-only modes.
/// The legacy room blob is never read by this client.
class RochySecureSyncService extends RochyCloudSyncService {
  RochySecureSyncService(this.account, {super.client});
  final RochyAccountService account;

  Object? _canonical(Object? value) {
    if (value is Map) {
      return {
        for (final key in (value.keys.map((k) => '$k').toList()..sort()))
          key: _canonical(value[key])
      };
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  RochySecureApi apiFor(FirebaseCoupleConfig config) =>
      RochySecureApi(config, account, client: httpClient);

  Future<String> _profile(RochySecureApi api) async {
    final role = await api.restoreBinding();
    if (role == null) {
      throw const FirebaseSyncException(
          'Vincula este dispositivo con Sam o Rochy antes de sincronizar.');
    }
    return role;
  }

  @override
  Future<bool> checkRoomExists(
      {required FirebaseCoupleConfig config, required String roomCode}) async {
    final api = apiFor(config);
    await _profile(api);
    return await api.read(
            'secureCouples/${RochyCloudSyncService.normalizeRoomCode(roomCode)}') !=
        null;
  }

  RochyNotebook _book(SecureDocument doc) => RochyNotebook(
        entity: BentoEntity.fromJson(
                Map<String, dynamic>.from(doc.data['entity'] as Map))
            .copyWith(
          ownerAuthorId: doc.data['ownerProfileId'] as String,
          sharingMode:
              NotebookSharingMode.fromKey(doc.data['sharingMode'] as String),
        ),
        nodes: (doc.data['nodes'] as List)
            .map((e) => BentoNode.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> _data(RochyNotebook book, Set<String> deleted) => {
        'ownerProfileId': book.entity.ownerAuthorId,
        'sharingMode': book.entity.sharingMode.name,
        'entity': book.entity.toJson(),
        'nodes': book.nodes.map((n) => n.toJson()).toList(),
        'deletedNodeIds': deleted.toList()..sort(),
        'updatedAt': DateTime.now().toUtc(),
      };

  Set<String> _deleted(SecureDocument? doc) =>
      Set<String>.from(doc?.data['deletedNodeIds'] as List? ?? []);

  RochyNotebook _merge(RochyNotebook local, RochyNotebook? remote,
      Set<String> deleted, String role) {
    if (remote == null) {
      return local.copyWith(
          nodes: local.nodes
              .where((n) =>
                  !deleted.contains(n.id) &&
                  !RochyCloudSyncService.isUnmodifiedDemoNode(n))
              .toList());
    }
    if (remote.entity.ownerAuthorId != role &&
        remote.entity.sharingMode == NotebookSharingMode.sharedViewOnly) {
      return remote;
    }
    // The pure merger intentionally excludes private imports. These documents
    // have already been authorized by Firebase for this profile, so merge their
    // contents temporarily under shared-edit semantics, restoring the real ACL.
    final merged = RochyCloudSyncService.mergeNotebooksPure(
      localNotebooks: [
        local.copyWith(
            entity: local.entity
                .copyWith(sharingMode: NotebookSharingMode.sharedEdit))
      ],
      incomingNotebooks: [
        remote.copyWith(
            entity: remote.entity
                .copyWith(sharingMode: NotebookSharingMode.sharedEdit))
      ],
      deletedIds: deleted,
      localOwner: role,
    ).notebooks.single;
    return merged.copyWith(
        entity:
            remote.entity.ownerAuthorId == role ? local.entity : remote.entity);
  }

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
    final api = apiFor(config);
    final role = await _profile(api);
    // A display-name switch cannot impersonate another profile.
    if (viewerAuthor != role) {
      throw const FirebaseSyncException(
          'El perfil seleccionado no coincide con el dispositivo vinculado.');
    }
    final roomId = RochyCloudSyncService.normalizeRoomCode(config.coupleRoomId);
    final sharedPath = 'secureCouples/$roomId';
    if (await api.read(sharedPath) == null) {
      await api.write(
          sharedPath,
          {
            'ownerProfileId': role,
            'members': {'samuel': true, 'rochy': true},
            'createdAt': DateTime.now().toUtc(),
            'updatedAt': DateTime.now().toUtc(),
          },
          create: true);
    }
    final sharedDocs = await api.list('$sharedPath/notebooks');
    final privateDocs = await api.list('profiles/$role/notebooks');
    final removed = [
      ...await api.list('$sharedPath/notebookDeletions'),
      ...await api.list('profiles/$role/notebookDeletions'),
    ];
    final removedIds = removed.map((doc) => doc.path.split('/').last).toSet();
    final shared = {for (final doc in sharedDocs) _book(doc).entity.id: doc};
    final private = {for (final doc in privateDocs) _book(doc).entity.id: doc};
    final allIds = <String>{
      ...localNotebooks.map((b) => b.entity.id),
      ...shared.keys,
      ...private.keys
    };
    final localById = {for (final book in localNotebooks) book.entity.id: book};
    final media = RochySecureMediaSession(api, mediaService);
    await media.initialize();
    final people = <String, String>{};
    for (final person in ['samuel', 'rochy']) {
      final path = '$sharedPath/people/$person';
      var document = await api.read(path);
      if (person == role) {
        document ??= await api.write(
            path,
            {
              'name': person == 'samuel' ? 'Sam' : 'Rochy',
              'avatarSource': '',
              'updatedAt': DateTime.now().toUtc()
            },
            create: true);
        final previous = document.data['avatarSource'] as String? ?? '';
        final candidate =
            person == 'samuel' ? partnerAAvatarUrl : partnerBAvatarUrl;
        var avatar = await media.upload(
            candidate.isEmpty ? previous : candidate, '$path/media');
        if (avatar.startsWith(RochyCloudSyncService.pendingMediaPrefix) &&
            previous.isNotEmpty) {
          avatar = previous;
        }
        if (avatar != previous) {
          document = await api.write(
              path,
              {
                ...document.data,
                'avatarSource': avatar,
                'updatedAt': DateTime.now().toUtc()
              },
              revision: document.revision);
        }
      }
      people[person] = document?.data['avatarSource'] as String? ?? '';
    }
    final result = <RochyNotebook>[];
    final deletedResult = <String>{...localDeletedIds};
    final acknowledged = <String>{};
    var added = 0, changed = 0;

    for (final id in allIds) {
      if (removedIds.contains(id)) {
        // A previous attempt may have saved the tombstone before the actual
        // delete completed. Finish it rather than hiding a readable cloud copy.
        final sharedDoc = shared[id], privateDoc = private[id];
        if (sharedDoc != null && sharedDoc.data['ownerProfileId'] == role) {
          await api.delete(sharedDoc);
        }
        if (privateDoc != null) await api.delete(privateDoc);
        deletedResult.add('__book__:$id');
        continue;
      }
      var local = localById[id];
      final sharedDoc = shared[id], privateDoc = private[id];
      final remoteDoc =
          local?.entity.sharingMode == NotebookSharingMode.privateOnly
              ? privateDoc ?? sharedDoc
              : sharedDoc ?? privateDoc;
      final remote = remoteDoc == null ? null : _book(remoteDoc);
      if (local == null && remote == null) continue;
      if (local != null && local.entity.ownerAuthorId.isEmpty) {
        local =
            local.copyWith(entity: local.entity.copyWith(ownerAuthorId: role));
      }
      // Do not import, upload or reveal another profile's cached private data.
      if (local != null &&
          !local.entity.syncsToCloud &&
          local.entity.ownerAuthorId != role) {
        local = null;
        if (remote == null) continue;
      }
      // A shared book removed from the authoritative server must disappear
      // from the partner's cache, instead of being recreated during sync.
      if (remote == null && local?.entity.ownerAuthorId != role) continue;
      final owner = remote?.entity.ownerAuthorId ?? local!.entity.ownerAuthorId;
      final visibilityMarker = localDeletedIds
          .where((value) => value.startsWith('__visibility__:$id:'))
          .firstOrNull;
      if (local != null && remote != null && owner == role) {
        final localTime =
            local.entity.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final remoteTime =
            remote.entity.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final explicitChange =
            visibilityMarker != null && !localTime.isBefore(remoteTime);
        final mode = explicitChange
            ? NotebookSharingMode.fromKey(visibilityMarker.split(':').last)
            : remote.entity.sharingMode;
        final entity =
            localTime.isAfter(remoteTime) ? local.entity : remote.entity;
        local = local.copyWith(
            entity: entity.copyWith(sharingMode: mode, ownerAuthorId: owner));
      }
      if (localDeletedIds.contains('__book__:$id') && owner == role) {
        final tombstone = {
          'ownerProfileId': role,
          'deletedAt': DateTime.now().toUtc()
        };
        if (sharedDoc != null) {
          await api.write('$sharedPath/notebookDeletions/$id', tombstone);
        }
        await api.write('profiles/$role/notebookDeletions/$id', tombstone);
        if (sharedDoc != null && sharedDoc.data['ownerProfileId'] == role) {
          await api.delete(sharedDoc);
        }
        if (privateDoc != null) await api.delete(privateDoc);
        continue;
      }
      final canWrite = owner == role ||
          remote?.entity.sharingMode == NotebookSharingMode.sharedEdit;
      final bookNodeIds = {
        ...?local?.nodes.map((n) => n.id),
        ...?remote?.nodes.map((n) => n.id)
      };
      final deleted = {
        ..._deleted(remoteDoc),
        if (owner == role && sharedDoc?.data['ownerProfileId'] == role)
          ..._deleted(sharedDoc),
        if (owner == role) ..._deleted(privateDoc),
        if (canWrite) ...localDeletedIds.where(bookNodeIds.contains)
      };
      var book = local == null ? remote! : _merge(local, remote, deleted, role);
      if (owner == role &&
          sharedDoc?.data['ownerProfileId'] == role &&
          privateDoc != null) {
        final other = identical(remoteDoc, sharedDoc) ? privateDoc : sharedDoc!;
        book = _merge(book, _book(other), deleted, role);
      }
      if (owner != role && remote != null) {
        book = book.copyWith(entity: remote.entity);
      }
      deletedResult.addAll(_deleted(remoteDoc));
      if (local == null) added += book.nodes.length;
      if (!canWrite) {
        result.add(book);
        continue;
      }

      final target = book.entity.syncsToCloud
          ? '$sharedPath/notebooks/$id'
          : 'profiles/$role/notebooks/$id';
      var targetDoc = book.entity.syncsToCloud ? sharedDoc : privateDoc;
      if (targetDoc != null && targetDoc.data['ownerProfileId'] != owner) {
        throw const FirebaseSyncException(
            'Hay un conflicto de propietario en un cuaderno.');
      }
      if (targetDoc == null) {
        final envelope = book.copyWith(
            entity: book.entity.copyWith(coverImageUrl: ''), nodes: const []);
        targetDoc = await api.write(target, _data(envelope, {}), create: true);
      }
      final cloudBook = await rewriteNotebookMedia(
          book, (source) => media.upload(source, '$target/media'));
      final next = _data(cloudBook, deleted);
      final old = Map<String, dynamic>.from(targetDoc.data)
        ..remove('updatedAt');
      final comparable = Map<String, dynamic>.from(next)..remove('updatedAt');
      if (jsonEncode(_canonical(old)) != jsonEncode(_canonical(comparable))) {
        await api.write(target, next, revision: targetDoc.revision);
        changed++;
      }
      // Changing visibility moves data. It never leaves a stale shared copy
      // or a publicly usable link to the former file location.
      if (!book.entity.syncsToCloud && sharedDoc != null && owner == role) {
        await api.delete(sharedDoc);
      }
      if (book.entity.syncsToCloud && privateDoc != null && owner == role) {
        await api.delete(privateDoc);
      }
      if (visibilityMarker != null && owner == role) {
        acknowledged.add(visibilityMarker);
      }
      result.add(kIsWeb ? cloudBook : book);
    }
    return CloudSyncResult(
        mergedLocalNotebooks: result,
        addedNodes: added,
        updatedNodes: changed,
        uploadedMedia: media.uploaded,
        downloadedMedia: 0,
        pendingMedia: media.pending.length,
        deletedNodeIds: deletedResult..removeAll(acknowledged),
        acknowledgedVisibilityChanges: acknowledged,
        partnerAAvatarUrl: people['samuel']!,
        partnerBAvatarUrl: people['rochy']!);
  }
}
