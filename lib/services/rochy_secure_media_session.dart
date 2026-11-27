import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'media_and_auth_service.dart';
import 'rochy_cloud_sync_service.dart';
import 'rochy_protected_media.dart';
import 'rochy_secure_api.dart';

class RochySecureMediaSession {
  RochySecureMediaSession(this.api, this.media);
  final RochySecureApi api;
  final MediaAndAuthService media;
  final pending = <String>{};
  int uploaded = 0;
  final _cache = <String, String>{};
  SharedPreferences? _prefs;
  String get _indexKey =>
      'rochy_protected_media_${api.config.projectId}_${api.account.authorId}';

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_indexKey);
    if (raw != null) {
      _cache.addAll(Map<String, String>.from(jsonDecode(raw) as Map));
    }
  }

  String _basename(String source) {
    if (source.startsWith(RochyCloudSyncService.pendingMediaPrefix)) {
      return Uri.decodeComponent(
          source.substring(RochyCloudSyncService.pendingMediaPrefix.length));
    }
    return source.split(RegExp(r'[/\\]')).last;
  }

  String _mime(String path) => switch (path.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'heic' => 'image/heic',
        'avif' => 'image/avif',
        'mp4' => 'video/mp4',
        'mov' => 'video/quicktime',
        'webm' => 'video/webm',
        'mp3' => 'audio/mpeg',
        'm4a' || 'aac' => 'audio/mp4',
        'ogg' => 'audio/ogg',
        'wav' => 'audio/wav',
        'flac' => 'audio/flac',
        _ => 'application/octet-stream',
      };

  Future<String> upload(String source, String prefix) async {
    if (source.trim().isEmpty || source.startsWith('assets/')) return source;
    final cacheKey = sha256.convert(utf8.encode('$prefix:$source')).toString();
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;
    final protected = RochyProtectedMedia(api.account, client: api.client);
    late List<int> bytes;
    var mime = _mime(source);
    if (RochyProtectedMedia.isProtected(source)) {
      final uri = Uri.parse(source);
      if (uri.host == api.config.storageBucket &&
          uri.pathSegments.single.startsWith('$prefix/')) {
        return source;
      }
      final response = await protected.response(source, api.config);
      bytes = response.bodyBytes;
      mime = response.headers['content-type'] ?? mime;
    } else if (source.startsWith('https://firebasestorage.googleapis.com/')) {
      final uri = Uri.parse(source);
      final bucket = uri.pathSegments.length > 2 ? uri.pathSegments[2] : '';
      if (bucket != api.config.storageBucket) return source;
      final response = await api.client
          .get(uri, headers: await protected.storageHeaders(api.config))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw const FirebaseSyncException(
            'No se pudo trasladar un archivo antiguo a su ubicación privada.');
      }
      bytes = response.bodyBytes;
      mime = response.headers['content-type'] ?? mime;
    } else if (source.startsWith('https://') || source.startsWith('http://')) {
      // Explicit external links remain external; device credentials never go
      // to arbitrary image/video hosts.
      return source;
    } else if (source.startsWith('data:')) {
      final data = Uri.parse(source).data!;
      bytes = data.contentAsBytes();
      mime = data.mimeType;
    } else {
      File? file;
      if (!kIsWeb) {
        final original = File(source);
        if (await original.exists()) file = original;
        if (file == null) {
          final name = _basename(source);
          if (name.isNotEmpty &&
              name != '.' &&
              name != '..' &&
              !name.contains('/') &&
              !name.contains('\\')) {
            final dir = await media.ensureMediaDir();
            final recovered = File('${dir.path}${Platform.pathSeparator}$name');
            if (await recovered.exists()) file = recovered;
          }
        }
      }
      if (file == null) {
        final marker = source
                .startsWith(RochyCloudSyncService.pendingMediaPrefix)
            ? source
            : '${RochyCloudSyncService.pendingMediaPrefix}${Uri.encodeComponent(_basename(source))}';
        pending.add(marker);
        return marker;
      }
      bytes = await file.readAsBytes();
      mime = _mime(file.path);
    }
    if (bytes.isEmpty ||
        bytes.length > 100 * 1024 * 1024 ||
        !RegExp(r'^(image|audio|video)/').hasMatch(mime)) {
      throw const FirebaseSyncException(
          'El archivo debe ser una foto, video o audio de hasta 100 MB.');
    }
    final object = '$prefix/${sha256.convert(bytes)}';
    final uri = Uri.https(
        'firebasestorage.googleapis.com',
        '/v0/b/${api.config.storageBucket}/o',
        {'uploadType': 'media', 'name': object});
    final response = await api.client
        .post(
          uri,
          headers: {
            ...await protected.storageHeaders(api.config),
            'Content-Type': mime
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw FirebaseSyncException(
          'La subida sigue pendiente (${response.statusCode}). Se reintentará automáticamente.');
    }
    final reference =
        RochyProtectedMedia.reference(api.config.storageBucket, object);
    _cache[cacheKey] = reference;
    await _prefs!.setString(_indexKey, jsonEncode(_cache));
    uploaded++;
    return reference;
  }
}
