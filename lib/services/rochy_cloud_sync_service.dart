import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/bento_node.dart';
import 'media_and_auth_service.dart';
import 'rochy_account_service.dart';
import 'rochy_secure_sync_service.dart';

final rochyCloudSyncServiceProvider = Provider<RochyCloudSyncService>((ref) {
  final account = ref.read(rochyAccountProvider);
  return RochySecureSyncService(account, client: account.httpClient);
});

class FirebaseCoupleConfig {
  const FirebaseCoupleConfig({
    this.projectId = defaultProjectId,
    this.storageBucket = defaultStorageBucket,
    this.apiKey = defaultApiKey,
    this.coupleRoomId = defaultRoomId,
    this.autoSyncEnabled = true,
  });

  static const String defaultProjectId = 'rochy-172d1';
  static const String defaultRoomId = 'sala-5314';
  static const String defaultStorageBucket = 'rochy-172d1.firebasestorage.app';
  static const String defaultApiKey = 'AIzaSyCIz_AmyJRln8VyA8K_7FlfGJ4kL2xfPO0';

  final String projectId;
  final String storageBucket;
  final String apiKey;
  final String coupleRoomId;
  final bool autoSyncEnabled;

  bool get isConfigured =>
      projectId.trim().isNotEmpty &&
      storageBucket.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      coupleRoomId.trim().isNotEmpty;

  FirebaseCoupleConfig copyWith({
    String? projectId,
    String? storageBucket,
    String? apiKey,
    String? coupleRoomId,
    bool? autoSyncEnabled,
  }) {
    return FirebaseCoupleConfig(
      projectId: projectId ?? this.projectId,
      storageBucket: storageBucket ?? this.storageBucket,
      apiKey: apiKey ?? this.apiKey,
      coupleRoomId: coupleRoomId ?? this.coupleRoomId,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'projectId': projectId.trim(),
        'storageBucket': storageBucket.trim(),
        'apiKey': apiKey.trim(),
        'coupleRoomId': coupleRoomId.trim(),
        'autoSyncEnabled': autoSyncEnabled,
        if (projectId.trim().isEmpty && apiKey.trim().isEmpty)
          'disconnected': true,
      };

  factory FirebaseCoupleConfig.fromJson(Map<String, dynamic> json) {
    final explicitlyDisconnected = json['disconnected'] as bool? ?? false;
    final rawProject = (json['projectId'] as String? ?? '').trim();
    final rawBucket = (json['storageBucket'] as String? ?? '').trim();
    final rawKey = (json['apiKey'] as String? ?? '').trim();

    if (explicitlyDisconnected) {
      return FirebaseCoupleConfig(
        projectId: rawProject,
        storageBucket: rawBucket,
        apiKey: rawKey,
        coupleRoomId:
            (json['coupleRoomId'] as String?)?.trim().isNotEmpty == true
                ? (json['coupleRoomId'] as String).trim()
                : defaultRoomId,
        autoSyncEnabled: json['autoSyncEnabled'] as bool? ?? false,
      );
    }

    return FirebaseCoupleConfig(
      projectId: rawProject.isNotEmpty ? rawProject : defaultProjectId,
      storageBucket: rawBucket.isNotEmpty ? rawBucket : defaultStorageBucket,
      apiKey: rawKey.isNotEmpty ? rawKey : defaultApiKey,
      coupleRoomId: (json['coupleRoomId'] as String?)?.trim().isNotEmpty == true
          ? (json['coupleRoomId'] as String).trim()
          : defaultRoomId,
      autoSyncEnabled: json['autoSyncEnabled'] as bool? ?? true,
    );
  }

  /// Extrae credenciales automáticamente si el usuario pega `google-services.json`
  /// o el bloque `firebaseConfig = { apiKey: ..., projectId: ..., storageBucket: ... }`.
  static FirebaseCoupleConfig? tryParseFromRaw(
    String rawText, {
    String currentRoomId = defaultRoomId,
    bool autoSyncEnabled = true,
  }) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return null;

    // 1. Intentar como google-services.json completo
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (map['project_info'] is Map) {
          final info = Map<String, dynamic>.from(map['project_info'] as Map);
          final projectId = (info['project_id'] as String? ?? '').trim();
          var bucket = (info['storage_bucket'] as String? ?? '').trim();
          if (bucket.isEmpty && projectId.isNotEmpty) {
            bucket = '$projectId.firebasestorage.app';
          }
          var apiKey = '';
          final clients = map['client'] as List<dynamic>? ?? const [];
          if (clients.isNotEmpty && clients.first is Map) {
            final c0 = Map<String, dynamic>.from(clients.first as Map);
            final keys = c0['api_key'] as List<dynamic>? ?? const [];
            if (keys.isNotEmpty && keys.first is Map) {
              apiKey =
                  (Map<String, dynamic>.from(keys.first as Map)['current_key']
                              as String? ??
                          '')
                      .trim();
            }
          }
          if (projectId.isNotEmpty && apiKey.isNotEmpty) {
            return FirebaseCoupleConfig(
              projectId: projectId,
              storageBucket: bucket,
              apiKey: apiKey,
              coupleRoomId: currentRoomId,
              autoSyncEnabled: autoSyncEnabled,
            );
          }
        }
        // JSON estándar con camelCase
        final pid = (map['projectId'] as String? ?? '').trim();
        final ak = (map['apiKey'] as String? ?? '').trim();
        var sb = (map['storageBucket'] as String? ?? '').trim();
        if (sb.isEmpty && pid.isNotEmpty) {
          sb = '$pid.firebasestorage.app';
        }
        if (pid.isNotEmpty && ak.isNotEmpty) {
          return FirebaseCoupleConfig(
            projectId: pid,
            storageBucket: sb,
            apiKey: ak,
            coupleRoomId: currentRoomId,
            autoSyncEnabled: autoSyncEnabled,
          );
        }
      }
    } catch (_) {}

    // 2. Extraer desde snippet JS de Firebase Console (`firebaseConfig = { ... }`)
    String extractField(String key) {
      final rx = RegExp(
        '''["']?$key["']?\\s*:\\s*["']([^"']+)["']''',
        caseSensitive: false,
      );
      return rx.firstMatch(trimmed)?.group(1)?.trim() ?? '';
    }

    final projectId = extractField('projectId');
    final apiKey = extractField('apiKey');
    var storageBucket = extractField('storageBucket');
    if (storageBucket.isEmpty && projectId.isNotEmpty) {
      storageBucket = '$projectId.firebasestorage.app';
    }

    if (projectId.isNotEmpty && apiKey.isNotEmpty) {
      return FirebaseCoupleConfig(
        projectId: projectId,
        storageBucket: storageBucket,
        apiKey: apiKey,
        coupleRoomId: currentRoomId,
        autoSyncEnabled: autoSyncEnabled,
      );
    }
    return null;
  }
}

class FirebaseSyncException implements Exception {
  const FirebaseSyncException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CloudSyncResult {
  const CloudSyncResult({
    required this.mergedLocalNotebooks,
    required this.addedNodes,
    required this.updatedNodes,
    required this.uploadedMedia,
    required this.downloadedMedia,
    this.pendingMedia = 0,
    this.acknowledgedVisibilityChanges = const <String>{},
    this.deletedNodeIds = const <String>{},
    this.partnerAAvatarUrl = '',
    this.partnerBAvatarUrl = '',
    this.remoteUpdatedBy = '',
    this.remoteUpdatedAtIso = '',
  });

  final List<RochyNotebook> mergedLocalNotebooks;
  final int addedNodes;
  final int updatedNodes;
  final int uploadedMedia;
  final int downloadedMedia;
  final int pendingMedia;
  final Set<String> acknowledgedVisibilityChanges;
  final Set<String> deletedNodeIds;
  final String partnerAAvatarUrl;
  final String partnerBAvatarUrl;
  final String remoteUpdatedBy;
  final String remoteUpdatedAtIso;
}

/// Sincronización bidireccional en la nube con Cloud Firestore + Firebase Storage
/// usando caché local permanente en `rochy_media/` y compresión automática previa.
class RochyCloudSyncService {
  RochyCloudSyncService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  http.Client get httpClient => _client;

  Future<RochyNotebook> rewriteNotebookMedia(
    RochyNotebook book,
    Future<String> Function(String) rewrite,
  ) =>
      _rewriteNotebookMediaAsync(book, rewrite);
  static const pendingMediaPrefix = 'rochy-pending-media:';

  String _mediaBasename(String raw) {
    final value = raw.startsWith(pendingMediaPrefix)
        ? Uri.decodeComponent(raw.substring(pendingMediaPrefix.length))
        : raw;
    return value.split(RegExp(r'[/\\]')).last;
  }

  Future<
      ({
        Map<String, String> localToRemote,
        Map<String, String> remoteToLocal,
        File indexFile,
      })> _loadMediaIndex(Directory mediaDir) async {
    final indexFile =
        File('${mediaDir.path}${Platform.pathSeparator}cloud_media_index.json');
    final l2r = <String, String>{};
    final r2l = <String, String>{};
    try {
      if (await indexFile.exists()) {
        final map = jsonDecode(await indexFile.readAsString());
        if (map is Map) {
          final rawL2R = map['localToRemote'] as Map? ?? const {};
          final rawR2L = map['remoteToLocal'] as Map? ?? const {};
          rawL2R.forEach((k, v) {
            if (k is String && v is String) l2r[k] = v;
          });
          rawR2L.forEach((k, v) {
            if (k is String && v is String) r2l[k] = v;
          });
        }
      }
    } catch (_) {}
    return (localToRemote: l2r, remoteToLocal: r2l, indexFile: indexFile);
  }

  Future<void> _saveMediaIndex(
    File indexFile,
    Map<String, String> l2r,
    Map<String, String> r2l,
  ) async {
    try {
      await indexFile.writeAsString(
        jsonEncode(<String, dynamic>{
          'localToRemote': l2r,
          'remoteToLocal': r2l,
        }),
        flush: true,
      );
    } catch (_) {}
  }

  static String normalizeRoomCode(String rawRoom) {
    final clean = rawRoom
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return clean.isEmpty ? FirebaseCoupleConfig.defaultRoomId : clean;
  }

  /// Extrae un código de sala desde texto libre (por ejemplo un mensaje de WhatsApp).
  static String extractRoomCode(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return '';
    final tagged = RegExp(
      r'(?:c[oó]digo|sala)\s*[:#]?\s*([A-Za-z0-9][A-Za-z0-9_-]{3,36})',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (tagged != null) {
      return normalizeRoomCode(tagged.group(1)!);
    }
    final token =
        RegExp(r'\b([A-Za-z0-9]+-[A-Za-z0-9_-]{2,})\b').firstMatch(trimmed);
    if (token != null) {
      return normalizeRoomCode(token.group(1)!);
    }
    return normalizeRoomCode(trimmed);
  }

  /// Genera un código legible y único para invitar a la pareja (ej. ROCHY-SAM-4821).
  static String generateRoomCode(String nameA, String nameB) {
    String cleanWord(String s, String fallback) {
      final w = s.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (w.isEmpty) return fallback;
      return w.length > 6 ? w.substring(0, 6) : w;
    }

    final a = cleanWord(nameB, 'ROCHY');
    final b = cleanWord(nameA, 'SAM');
    final rng = math.Random.secure();
    final digits = (1000 + rng.nextInt(9000)).toString();
    return '$a-$b-$digits';
  }

  /// Verifica si ya existe una sala creada en Cloud Firestore para unirse con código.
  Future<bool> checkRoomExists({
    required FirebaseCoupleConfig config,
    required String roomCode,
  }) async {
    if (!config.isConfigured) return false;
    final projectId = config.projectId.trim();
    final apiKey = config.apiKey.trim();
    final slug = normalizeRoomCode(roomCode);
    final docUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/rochy_couples/$slug?key=$apiKey',
    );
    final resp = await _client.get(docUri).timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) return true;
    if (resp.statusCode == 404) return false;
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw const FirebaseSyncException(
        'Acceso denegado en Cloud Firestore. Revisa las reglas de rochy_couples.',
      );
    }
    throw FirebaseSyncException(
      'No se pudo comprobar la sala en Firestore (${resp.statusCode}).',
    );
  }

  String _safeRoomSlug(String rawRoom) => normalizeRoomCode(rawRoom);

  String _normalizeBucket(String rawBucket) {
    var b = rawBucket.trim();
    if (b.startsWith('gs://')) b = b.substring(5);
    if (b.contains('/')) b = b.split('/').first;
    return b;
  }

  String _extension(String path) {
    final clean = path.split('?').first;
    final lastSlash = clean.lastIndexOf(RegExp(r'[/\\]'));
    final name = lastSlash >= 0 ? clean.substring(lastSlash + 1) : clean;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot >= name.length - 1) return '';
    return name.substring(dot).toLowerCase();
  }

  String _contentTypeForExt(String ext) => switch (ext) {
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.mp4' => 'video/mp4',
        '.mov' => 'video/quicktime',
        '.webm' => 'video/webm',
        '.m4a' || '.aac' => 'audio/mp4',
        '.mp3' => 'audio/mpeg',
        _ => 'application/octet-stream',
      };

  bool _isLocalFilePath(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return false;
    if (t.startsWith('http://') ||
        t.startsWith('https://') ||
        t.startsWith('assets/') ||
        t.startsWith('data:') ||
        t.startsWith('rochy_media://')) {
      return false;
    }
    if (kIsWeb) return false;
    try {
      return File(t).existsSync();
    } catch (_) {
      return false;
    }
  }

  bool _isImageExt(String ext) =>
      ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp';

  bool _isFirebaseStorageUrl(String raw) {
    return raw.startsWith('https://firebasestorage.googleapis.com/') &&
        raw.contains('/o/');
  }

  String _remoteFileNameFromUrl(String url) {
    final noQuery = url.split('?').first;
    final decoded = Uri.decodeComponent(noQuery);
    final segments = decoded.split('/');
    final rawName = segments.isNotEmpty ? segments.last : 'media.bin';
    return rawName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  Future<CloudSyncResult> syncCoupleWorkspace({
    required FirebaseCoupleConfig config,
    required List<RochyNotebook> localNotebooks,
    required String viewerAuthor,
    required MediaAndAuthService mediaService,
    Set<String> localDeletedIds = const <String>{},
    String partnerAAvatarUrl = '',
    String partnerBAvatarUrl = '',
  }) async {
    if (!config.isConfigured) {
      throw const FirebaseSyncException(
        'Completa los datos de tu proyecto Firebase primero.',
      );
    }

    final projectId = config.projectId.trim();
    final bucket = _normalizeBucket(config.storageBucket);
    final apiKey = config.apiKey.trim();
    final roomId = _safeRoomSlug(config.coupleRoomId);

    final mediaDir = kIsWeb ? null : await mediaService.ensureMediaDir();
    final idx = mediaDir == null ? null : await _loadMediaIndex(mediaDir);
    final prefs = kIsWeb ? await SharedPreferences.getInstance() : null;
    final webIndexKey = 'rochy_cloud_media_${projectId}_$bucket' '_$roomId';
    final webIndex = prefs?.getString(webIndexKey);
    final l2r = idx?.localToRemote ??
        <String, String>{
          if (webIndex != null)
            ...Map<String, String>.from(jsonDecode(webIndex) as Map),
        };
    final r2l = idx?.remoteToLocal ?? <String, String>{};

    var downloadedMedia = 0;
    var uploadedMedia = 0;
    final pendingMedia = <String>{};

    // 1. Descargar documento actual en Cloud Firestore (GET)
    final docUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/rochy_couples/$roomId?key=$apiKey',
    );

    final getResp = await _client.get(docUri).timeout(
          const Duration(seconds: 20),
        );

    var remoteNotebooks = const <RochyNotebook>[];
    var remoteDeletedIds = <String>{};
    var remoteAvatarA = '';
    var remoteAvatarB = '';
    var remotePayloadB64 = '';
    var remoteMetaB64 = '';
    var preservedRemoteMeta = <String, dynamic>{};
    var remoteUpdatedBy = '';
    var remoteUpdatedAtIso = '';

    if (getResp.statusCode == 200) {
      final bodyMap =
          jsonDecode(getResp.body) as Map<String, dynamic>? ?? const {};
      final fields = bodyMap['fields'] as Map<String, dynamic>? ?? const {};
      final updatedByField =
          fields['updatedBy'] as Map<String, dynamic>? ?? const {};
      remoteUpdatedBy = (updatedByField['stringValue'] as String? ?? '').trim();
      final updatedAtField =
          fields['updatedAt'] as Map<String, dynamic>? ?? const {};
      remoteUpdatedAtIso =
          (updatedAtField['timestampValue'] as String? ?? '').trim();

      final encodedField =
          fields['payloadGzipBase64'] as Map<String, dynamic>? ?? const {};
      final b64 = encodedField['stringValue'] as String? ?? '';
      remotePayloadB64 = b64;
      if (b64.isNotEmpty) {
        final rawBytes = const GZipDecoder().decodeBytes(base64Decode(b64));
        final decodedJson = jsonDecode(utf8.decode(rawBytes));
        if (decodedJson is List) {
          remoteNotebooks = decodedJson
              .map(
                (e) => RochyNotebook.fromJson(
                  Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
                ),
              )
              .toList(growable: false);
        }
      }

      final metaField =
          fields['coupleMetaGzipBase64'] as Map<String, dynamic>? ?? const {};
      final metaB64 = metaField['stringValue'] as String? ?? '';
      remoteMetaB64 = metaB64;
      if (metaB64.isNotEmpty) {
        try {
          final rawMeta =
              const GZipDecoder().decodeBytes(base64Decode(metaB64));
          final decodedMeta = jsonDecode(utf8.decode(rawMeta));
          if (decodedMeta is Map) {
            preservedRemoteMeta = Map<String, dynamic>.from(decodedMeta);
            final delList =
                decodedMeta['deletedNodeIds'] as List<dynamic>? ?? const [];
            remoteDeletedIds = delList
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toSet();
            remoteAvatarA =
                (decodedMeta['partnerAAvatarUrl'] as String? ?? '').trim();
            remoteAvatarB =
                (decodedMeta['partnerBAvatarUrl'] as String? ?? '').trim();
          }
        } catch (_) {}
      }
    } else if (getResp.statusCode == 401 || getResp.statusCode == 403) {
      throw const FirebaseSyncException(
        'Acceso denegado en Cloud Firestore. Revisa tu API Key y que las reglas de Firestore permitan lectura/escritura en rochy_couples.',
      );
    } else if (getResp.statusCode != 404) {
      throw FirebaseSyncException(
        'Error de conexión con Firestore (${getResp.statusCode}).',
      );
    }

    final allDeletedIds = <String>{
      ...localDeletedIds,
      ...remoteDeletedIds,
      for (final book in [...localNotebooks, ...remoteNotebooks])
        for (final node in book.nodes)
          if (isUnmodifiedDemoNode(node)) node.id,
    };

    // 2. Materializar multimedia remota en caché local permanente y preparar subida
    Future<String> resolveRemoteToLocal(String raw) async {
      final trimmed = raw.trim();
      if (!kIsWeb &&
          trimmed.isNotEmpty &&
          !trimmed.startsWith('http://') &&
          !trimmed.startsWith('https://') &&
          !trimmed.startsWith('data:') &&
          !trimmed.startsWith('assets/')) {
        if (_isLocalFilePath(trimmed)) return raw;
        final name = _mediaBasename(trimmed);
        if (name.isNotEmpty && name != '.' && name != '..') {
          final recovered =
              File('${mediaDir!.path}${Platform.pathSeparator}$name');
          if (await recovered.exists()) return recovered.path;
        }
      }
      if (kIsWeb || !_isFirebaseStorageUrl(trimmed)) return raw;

      final mapped = r2l[trimmed];
      if (mapped != null && File(mapped).existsSync()) {
        l2r[mapped] = trimmed;
        return mapped;
      }

      final fileName = _remoteFileNameFromUrl(trimmed);
      final destFile =
          File('${mediaDir!.path}${Platform.pathSeparator}cloud_$fileName');
      if (await destFile.exists() && await destFile.length() > 0) {
        r2l[trimmed] = destFile.path;
        l2r[destFile.path] = trimmed;
        return destFile.path;
      }

      try {
        final resp = await _client
            .get(Uri.parse(trimmed))
            .timeout(const Duration(seconds: 45));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          await destFile.writeAsBytes(resp.bodyBytes, flush: true);
          r2l[trimmed] = destFile.path;
          l2r[destFile.path] = trimmed;
          downloadedMedia++;
          return destFile.path;
        }
      } catch (_) {}
      return raw;
    }

    Future<String> uploadLocalToRemote(String raw) async {
      var trimmed = raw.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('http://') ||
          trimmed.startsWith('https://') ||
          trimmed.startsWith('assets/')) {
        return raw;
      }
      final originalInput = trimmed;
      if (!trimmed.startsWith('data:') && !_isLocalFilePath(trimmed)) {
        // Old snapshots can contain a path from a different app sandbox.
        // Recover by filename on the device that still has the actual bytes.
        final knownUrl = l2r[trimmed] ?? l2r['$bucket/$roomId:$trimmed'];
        if (knownUrl != null && _isFirebaseStorageUrl(knownUrl)) {
          return knownUrl;
        }
        final name = _mediaBasename(trimmed);
        if (!kIsWeb && name.isNotEmpty && name != '.' && name != '..') {
          final recovered =
              File('${mediaDir!.path}${Platform.pathSeparator}$name');
          if (await recovered.exists()) trimmed = recovered.path;
        }
        if (!_isLocalFilePath(trimmed)) {
          final marker = trimmed.startsWith(pendingMediaPrefix)
              ? trimmed
              : '$pendingMediaPrefix${Uri.encodeComponent(name)}';
          pendingMedia.add(marker);
          return marker;
        }
      }
      final isInline = trimmed.startsWith('data:');

      final cacheKey =
          kIsWeb ? _stableHash(trimmed) : '$bucket/$roomId:$trimmed';
      final cachedUrl = l2r[cacheKey];
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        return cachedUrl;
      }

      var ext = _extension(trimmed);
      late List<int> bytes;
      if (isInline) {
        final data = Uri.parse(trimmed).data!;
        bytes = data.contentAsBytes();
        ext = switch (data.mimeType) {
          'image/png' => '.png',
          'image/webp' => '.webp',
          'image/jpeg' => '.jpg',
          'video/webm' => '.webm',
          'video/quicktime' => '.mov',
          'video/mp4' => '.mp4',
          'audio/mpeg' => '.mp3',
          'audio/webm' => '.webm',
          'audio/mp4' => '.m4a',
          _ => '.bin',
        };
      } else {
        var fileToUpload = File(trimmed);
        if (ext.isEmpty) ext = '.bin';
        if (_isImageExt(ext) && await fileToUpload.length() > 350 * 1024) {
          final compressed =
              await mediaService.processCroppedAndCompressedImage(
            sourcePath: trimmed,
            maxDimension: 1280,
            quality: 78,
          );
          if (compressed != null) {
            fileToUpload = File(compressed.path);
            ext = _extension(compressed.path);
          }
        }
        bytes = await fileToUpload.readAsBytes();
      }
      final nameHash = _stableHash(
        base64Encode(bytes),
      );
      final remoteName = 'm_$nameHash$ext';
      final objectPath = 'couples/$roomId/media/$remoteName';
      final encodedPath = Uri.encodeComponent(objectPath);
      final uploadUri = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o?uploadType=media&name=$encodedPath',
      );

      final uploadResp = await _client
          .post(
            uploadUri,
            headers: <String, String>{
              'Content-Type': _contentTypeForExt(ext),
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));

      if (uploadResp.statusCode == 200 || uploadResp.statusCode == 201) {
        String downloadUrl =
            'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media';
        try {
          final meta = jsonDecode(uploadResp.body);
          if (meta is Map && meta['downloadTokens'] is String) {
            final token = (meta['downloadTokens'] as String).split(',').first;
            if (token.isNotEmpty) {
              downloadUrl =
                  'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
            }
          }
        } catch (_) {}
        l2r[cacheKey] = downloadUrl;
        l2r['$bucket/$roomId:$originalInput'] = downloadUrl;
        r2l[downloadUrl] = trimmed;
        // Keep successful uploads across a later failure or app restart.
        if (idx != null) await _saveMediaIndex(idx.indexFile, l2r, r2l);
        if (prefs != null) await prefs.setString(webIndexKey, jsonEncode(l2r));
        uploadedMedia++;
        return downloadUrl;
      } else if (uploadResp.statusCode == 401 || uploadResp.statusCode == 403) {
        throw const FirebaseSyncException(
          'Permiso denegado en Firebase Storage. Revisa que tu bucket esté creado en Plan Blaze y sus reglas permitan couples/.',
        );
      }
      throw FirebaseSyncException(
        'No se pudo subir un archivo a Firebase Storage (${uploadResp.statusCode}). Intenta sincronizar de nuevo.',
      );
    }

    Future<({String localPath, String remoteUrl})> syncAvatarPair(
      String localInput,
      String remoteUrl,
    ) async {
      final localTrim = localInput.trim();
      final remoteTrim = remoteUrl.trim();
      final hasValidLocal = localTrim.isNotEmpty &&
          (localTrim.startsWith('data:') || _isLocalFilePath(localTrim));

      if (hasValidLocal) {
        final knownRemote = l2r[localTrim];
        if (knownRemote == null) {
          final uploaded = await uploadLocalToRemote(localTrim);
          return (
            localPath: localTrim,
            remoteUrl: _isFirebaseStorageUrl(uploaded) ? uploaded : remoteTrim,
          );
        }
        if (remoteTrim.isNotEmpty && knownRemote != remoteTrim) {
          final downloaded = await resolveRemoteToLocal(remoteTrim);
          return (localPath: downloaded, remoteUrl: remoteTrim);
        }
        return (
          localPath: localTrim,
          remoteUrl: remoteTrim.isNotEmpty ? remoteTrim : knownRemote,
        );
      }

      if (remoteTrim.isNotEmpty) {
        if (_isFirebaseStorageUrl(remoteTrim)) {
          final downloaded = await resolveRemoteToLocal(remoteTrim);
          return (localPath: downloaded, remoteUrl: remoteTrim);
        }
        return (
          localPath: remoteTrim,
          remoteUrl: await uploadLocalToRemote(remoteTrim)
        );
      }

      if (_isFirebaseStorageUrl(localTrim)) {
        final downloaded = await resolveRemoteToLocal(localTrim);
        return (localPath: downloaded, remoteUrl: localTrim);
      }

      return (localPath: '', remoteUrl: '');
    }

    final localizedRemoteBooks = <RochyNotebook>[];
    for (final book in remoteNotebooks) {
      localizedRemoteBooks.add(
        await _rewriteNotebookMediaAsync(book, resolveRemoteToLocal),
      );
    }

    final syncedAvatarA =
        await syncAvatarPair(partnerAAvatarUrl, remoteAvatarA);
    final syncedAvatarB =
        await syncAvatarPair(partnerBAvatarUrl, remoteAvatarB);

    // 3. Fusionar cuadernos locales + remotos respetando borrados y respuestas dobles
    final merged = mergeNotebooksPure(
      localNotebooks: localNotebooks,
      incomingNotebooks: localizedRemoteBooks,
      deletedIds: allDeletedIds,
      localOwner: viewerAuthor,
    );

    // 4. Preparar copia para subir a la nube: solo cuadernos Compartidos o Solo vista
    //    (los cuadernos Privados jamás salen del dispositivo local).
    final cloudPayloadBooks = <RochyNotebook>[];
    for (final book in merged.notebooks) {
      if (!book.entity.syncsToCloud) continue;
      cloudPayloadBooks.add(
        await _rewriteNotebookMediaAsync(book, uploadLocalToRemote),
      );
    }

    // 5. Subir documento fusionado a Firestore (PATCH con compresión GZip + Base64)
    final encodedGzip = base64Encode(
      const GZipEncoder().encode(
        utf8.encode(
          jsonEncode(
            cloudPayloadBooks.map((b) => b.toJson()).toList(growable: false),
          ),
        ),
      ),
    );
    final encodedMetaGzip = base64Encode(
      const GZipEncoder().encode(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            ...preservedRemoteMeta,
            'deletedNodeIds': allDeletedIds.toList(growable: false),
            'partnerAAvatarUrl': syncedAvatarA.remoteUrl,
            'partnerBAvatarUrl': syncedAvatarB.remoteUrl,
          }),
        ),
      ),
    );

    final hasCloudDiff = getResp.statusCode == 404 ||
        encodedGzip != remotePayloadB64 ||
        encodedMetaGzip != remoteMetaB64;

    if (hasCloudDiff) {
      final patchUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/rochy_couples/$roomId?updateMask.fieldPaths=payloadGzipBase64&updateMask.fieldPaths=coupleMetaGzipBase64&updateMask.fieldPaths=updatedAt&updateMask.fieldPaths=updatedBy&key=$apiKey',
      );

      final patchResp = await _client
          .patch(
            patchUri,
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(<String, dynamic>{
              'fields': <String, dynamic>{
                'payloadGzipBase64': <String, dynamic>{
                  'stringValue': encodedGzip,
                },
                'coupleMetaGzipBase64': <String, dynamic>{
                  'stringValue': encodedMetaGzip,
                },
                'updatedAt': <String, dynamic>{
                  'timestampValue': DateTime.now().toUtc().toIso8601String(),
                },
                'updatedBy': <String, dynamic>{'stringValue': viewerAuthor},
              },
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (patchResp.statusCode != 200) {
        if (patchResp.statusCode == 401 || patchResp.statusCode == 403) {
          throw const FirebaseSyncException(
            'No tienes permiso de escritura en Cloud Firestore. Revisa las reglas de rochy_couples.',
          );
        }
        throw FirebaseSyncException(
          'No se pudo guardar en Cloud Firestore (${patchResp.statusCode}).',
        );
      }
    }

    if (idx != null) await _saveMediaIndex(idx.indexFile, l2r, r2l);
    if (prefs != null) {
      // Cache only portable URLs; the selected bytes remain in the notebook.
      await prefs.setString(webIndexKey, jsonEncode(l2r));
    }

    return CloudSyncResult(
      mergedLocalNotebooks: kIsWeb
          ? merged.notebooks
              .map((book) =>
                  cloudPayloadBooks
                      .where((cloud) => cloud.entity.id == book.entity.id)
                      .firstOrNull ??
                  book)
              .toList(growable: false)
          : merged.notebooks,
      addedNodes: merged.addedNodes,
      updatedNodes: merged.updatedNodes,
      uploadedMedia: uploadedMedia,
      downloadedMedia: downloadedMedia,
      pendingMedia: pendingMedia.length,
      deletedNodeIds: allDeletedIds,
      partnerAAvatarUrl: syncedAvatarA.localPath,
      partnerBAvatarUrl: syncedAvatarB.localPath,
      remoteUpdatedBy: remoteUpdatedBy,
      remoteUpdatedAtIso: remoteUpdatedAtIso,
    );
  }

  String _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final code in utf8.encode(input)) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static const Set<String> legacyDemoNodeIds = <String>{
    'sam_about_him',
    'sam_flip_coffee',
    'sam_audio_song',
    'sam_checklist_details',
    'nos_countdown_together',
    'nos_quote_duo',
    'nos_hero_place',
    'nos_checklist_dreams',
    'nos_plan_ticket_surprise',
    'nos_chat_funny',
    'nos_couple_question_1',
    'node_hero_cafe',
    'node_flip_coffee',
    'node_checklist_details',
    'node_quote_peace',
    'node_pin_baloco',
    'node_audio_song',
    'node_pin_sunday',
    'node_palette_mood',
    'node_countdown_days',
    'node_love_letter',
  };

  /// Identify shipped examples by their reserved ID and original content.
  /// User edits to their text are retained, even if the ID is unchanged.
  static bool isUnmodifiedDemoNode(BentoNode node) {
    if (legacyDemoNodeIds.contains(node.id)) {
      return node.updatedAt == null || node.updatedAt == node.createdAt;
    }
    final p = node.payload.toJson();
    return switch (node.id) {
      'starter_about_her' => p['title'] == 'Sobre ella' &&
          jsonEncode(p['entries']) ==
              jsonEncode([
                {'prefix': 'Ella es', 'detail': 'mi calma en cualquier día'},
                {
                  'prefix': 'Ella tiene',
                  'detail': 'una sonrisa que lo ilumina todo'
                },
                {
                  'prefix': 'Ella siempre',
                  'detail': 'encuentra magia en lo pequeño'
                },
              ]),
      'starter_quote_her' => p['quoteText'] ==
              'Con ella hasta el silencio se siente como compañía.' &&
          p['contextLabel'] == 'Notas sobre ella',
      'starter_countdown_her' => p['title'] == 'Nuestro comienzo' &&
          p['subtitle'] == 'Días guardando momentos' &&
          p['targetDate'] == '2023-10-14T00:00:00.000',
      'starter_checklist_her' => p['title'] == 'Pequeñas cosas que ama' &&
          jsonEncode((p['items'] as List).map((e) => e['text']).toList()) ==
              jsonEncode([
                'Un buen café tibio por la tarde',
                'Caminar sin prisa al atardecer'
              ]),
      _ => false,
    };
  }

  static ({List<RochyNotebook> notebooks, int addedNodes, int updatedNodes})
      mergeNotebooksPure({
    required List<RochyNotebook> localNotebooks,
    required List<RochyNotebook> incomingNotebooks,
    Set<String> deletedIds = const <String>{},
    String localOwner = 'samuel',
  }) {
    bool isDeletedBook(String bookId) =>
        deletedIds.contains('__book__:$bookId');
    bool isDeletedNode(BentoNode n) =>
        deletedIds.contains(n.id) || isUnmodifiedDemoNode(n);

    if (incomingNotebooks.isEmpty) {
      var deletedLocally = 0;
      final keptBooks = localNotebooks
          .where((b) => !isDeletedBook(b.entity.id))
          .toList(growable: false);
      final baseBooks = keptBooks.isNotEmpty ? keptBooks : localNotebooks;
      final filtered = baseBooks.map((b) {
        final kept =
            b.nodes.where((n) => !isDeletedNode(n)).toList(growable: false);
        deletedLocally += b.nodes.length - kept.length;
        return b.copyWith(nodes: kept);
      }).toList(growable: false);
      return (
        notebooks: List<RochyNotebook>.unmodifiable(filtered),
        addedNodes: 0,
        updatedNodes: deletedLocally,
      );
    }

    var addedNodes = 0;
    var updatedNodes = 0;
    final booksById = <String, RochyNotebook>{
      for (final b in localNotebooks)
        if (!isDeletedBook(b.entity.id))
          b.entity.id: b.copyWith(
            nodes:
                b.nodes.where((n) => !isDeletedNode(n)).toList(growable: false),
          ),
    };
    final orderedIds = <String>[
      for (final b in localNotebooks)
        if (!isDeletedBook(b.entity.id)) b.entity.id,
    ];

    for (final incoming in incomingNotebooks) {
      final bookId = incoming.entity.id;
      if (isDeletedBook(bookId) || !incoming.entity.syncsToCloud) continue;
      final local = booksById[bookId];
      if (local == null) {
        final keptNodes = incoming.nodes
            .where((n) => !isDeletedNode(n))
            .toList(growable: false);
        booksById[bookId] = incoming.copyWith(nodes: keptNodes);
        orderedIds.add(bookId);
        addedNodes += keptNodes.length;
        continue;
      }

      // A remote shared ID must never overwrite a local private notebook.
      if (!local.entity.syncsToCloud) continue;
      if (incoming.entity.isReadOnlyFor(localOwner)) {
        final keptNodes = incoming.nodes
            .where((n) => !isDeletedNode(n))
            .toList(growable: false);
        booksById[bookId] = incoming.copyWith(nodes: keptNodes);
        updatedNodes += keptNodes.length;
        continue;
      }
      final incomingMap = <String, BentoNode>{
        for (final n in incoming.nodes)
          if (!isDeletedNode(n)) n.id: n,
      };
      final mergedNodes = <BentoNode>[];
      final handledIds = <String>{};

      for (final localNode in local.nodes) {
        handledIds.add(localNode.id);
        if (isDeletedNode(localNode)) {
          updatedNodes++;
          continue;
        }
        final remoteNode = incomingMap[localNode.id];
        if (remoteNode == null) {
          mergedNodes.add(localNode);
          continue;
        }
        final merged = _mergeNodePair(localNode, remoteNode, localOwner);
        mergedNodes.add(merged);
        if (!identical(merged, localNode)) {
          updatedNodes++;
        }
      }

      for (final remoteNode in incoming.nodes) {
        if (!handledIds.contains(remoteNode.id) && !isDeletedNode(remoteNode)) {
          mergedNodes.add(remoteNode);
          addedNodes++;
        }
      }

      final nextEntity = (incoming.entity.ownerAuthorId.isNotEmpty &&
              incoming.entity.ownerAuthorId != localOwner)
          ? incoming.entity
          : local.entity;
      booksById[bookId] = local.copyWith(
        entity: nextEntity,
        nodes: mergedNodes,
      );
    }

    return (
      notebooks: List<RochyNotebook>.unmodifiable(<RochyNotebook>[
        for (final id in orderedIds)
          if (booksById[id] != null) booksById[id]!,
      ]),
      addedNodes: addedNodes,
      updatedNodes: updatedNodes,
    );
  }

  static BentoNode _mergeNodePair(
    BentoNode localNode,
    BentoNode remoteNode,
    String localOwner,
  ) {
    final remoteWins =
        remoteNode.effectiveUpdatedAt.isAfter(localNode.effectiveUpdatedAt);
    var merged = remoteWins ? remoteNode : localNode;
    final other = remoteWins ? localNode : remoteNode;

    if (merged.partnerReplyText.trim().isEmpty &&
        other.partnerReplyText.trim().isNotEmpty) {
      merged = merged.copyWith(
        partnerReplyText: other.partnerReplyText,
        partnerReplyAuthor: other.partnerReplyAuthor,
      );
    }

    if (localNode.payload is CoupleQuestionPayload &&
        remoteNode.payload is CoupleQuestionPayload) {
      final lp = localNode.payload as CoupleQuestionPayload;
      final rp = remoteNode.payload as CoupleQuestionPayload;

      String pickAnswer({
        required String localAns,
        required String remoteAns,
        required String ownerKey,
      }) {
        final lt = localAns.trim();
        final rt = remoteAns.trim();
        if (lt == rt) return localAns;
        if (lt.isEmpty) return remoteAns;
        if (rt.isEmpty) return localAns;
        return localOwner == ownerKey ? localAns : remoteAns;
      }

      final baseQ = merged.payload as CoupleQuestionPayload;
      final nextSamuel = pickAnswer(
        localAns: lp.answerSamuel,
        remoteAns: rp.answerSamuel,
        ownerKey: 'samuel',
      );
      final nextRochy = pickAnswer(
        localAns: lp.answerRochy,
        remoteAns: rp.answerRochy,
        ownerKey: 'rochy',
      );
      if (nextSamuel != baseQ.answerSamuel || nextRochy != baseQ.answerRochy) {
        final latestTime = remoteWins
            ? remoteNode.effectiveUpdatedAt
            : localNode.effectiveUpdatedAt;
        merged = merged.copyWith(
          payload: baseQ.copyWith(
            answerSamuel: nextSamuel,
            answerRochy: nextRochy,
          ),
          updatedAt: latestTime,
        );
      }
    }

    return merged;
  }

  Future<RochyNotebook> _rewriteNotebookMediaAsync(
    RochyNotebook book,
    Future<String> Function(String raw) rewrite,
  ) async {
    final rewrittenCover = await rewrite(book.entity.coverImageUrl);
    final rewrittenNodes = <BentoNode>[];
    for (final node in book.nodes) {
      rewrittenNodes.add(
        node.copyWith(
          payload: await _rewritePayloadMediaAsync(node.payload, rewrite),
        ),
      );
    }
    return book.copyWith(
      entity: book.entity.copyWith(coverImageUrl: rewrittenCover),
      nodes: rewrittenNodes,
    );
  }

  Future<BentoPayload> _rewritePayloadMediaAsync(
    BentoPayload payload,
    Future<String> Function(String raw) rewrite,
  ) async {
    switch (payload) {
      case final PhotoHeroPayload p:
        return p.copyWith(imageUrl: await rewrite(p.imageUrl));
      case final VideoMemoryPayload p:
        return p.copyWith(
          videoSource: await rewrite(p.videoSource),
          thumbnailUrl: await rewrite(p.thumbnailUrl),
        );
      case final FlipDetailPayload p:
        return p.copyWith(localAudioPath: await rewrite(p.localAudioPath));
      case final AudioNotePayload p:
        return p.copyWith(
          coverImageUrl: await rewrite(p.coverImageUrl),
          localAudioPath: await rewrite(p.localAudioPath),
        );
      case final LocationPinPayload p:
        return p.copyWith(imageUrl: await rewrite(p.imageUrl));
      case final PhotoStripPayload p:
        final urls = <String>[];
        for (final u in p.imageUrls) {
          urls.add(await rewrite(u));
        }
        return p.copyWith(imageUrls: urls);
      case final CravingRecipePayload p:
        return p.copyWith(imageUrl: await rewrite(p.imageUrl));
      case final BookMoviePayload p:
        return p.copyWith(imageUrl: await rewrite(p.imageUrl));
      case final PolaroidThreadPayload p:
        final items = <PolaroidThreadItem>[];
        for (final it in p.items) {
          items.add(it.copyWith(imageUrl: await rewrite(it.imageUrl)));
        }
        return p.copyWith(items: items);
      case final WardrobeClosetPayload p:
        final items = <WardrobeItem>[];
        for (final it in p.items) {
          items.add(it.copyWith(imageUrl: await rewrite(it.imageUrl)));
        }
        return p.copyWith(items: items);
      case QuotePayload() ||
            CheckListPayload() ||
            CountdownPayload() ||
            PaletteMoodPayload() ||
            GiftWishPayload() ||
            LoveLetterPayload() ||
            HabitChipsPayload() ||
            MoodPulsePayload() ||
            PlanTicketPayload() ||
            TravelPassportPayload() ||
            SavedChatPayload() ||
            VintageTicketPayload() ||
            SketchDoodlePayload() ||
            CoupleQuestionPayload() ||
            AboutHerPayload():
        return payload;
    }
  }
}
