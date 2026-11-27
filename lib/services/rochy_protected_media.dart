import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'media_object_url.dart';
import 'rochy_account_service.dart';
import 'rochy_cloud_sync_service.dart';

final rochyProtectedMediaProvider =
    Provider((ref) => RochyProtectedMedia(ref.read(rochyAccountProvider)));

class ProtectedMediaPlayback {
  const ProtectedMediaPlayback(this.url, this.headers, this.release);
  final String url;
  final Map<String, String> headers;
  final void Function() release;
}

/// Opaque references identify objects, not publicly usable download links.
class RochyProtectedMedia {
  RochyProtectedMedia(this.account, {http.Client? client})
      : _client = client ?? http.Client();
  final RochyAccountService account;
  final http.Client _client;
  static bool isProtected(String source) =>
      source.startsWith('rochy-storage://');
  static String reference(String bucket, String object) =>
      'rochy-storage://$bucket/${Uri.encodeComponent(object)}';

  static Uri downloadUri(String source, FirebaseCoupleConfig config) {
    final uri = Uri.parse(source);
    if (uri.scheme != 'rochy-storage' ||
        uri.host != config.storageBucket ||
        uri.pathSegments.length != 1) {
      throw const RochyAccountException(
          'La referencia del archivo no pertenece a este proyecto.');
    }
    final object = uri.pathSegments.single;
    if (!(object.startsWith('profiles/') ||
            object.startsWith('secureCouples/')) ||
        object.split('/').any((p) => p == '.' || p == '..')) {
      throw const RochyAccountException(
          'La referencia del archivo no es válida.');
    }
    return Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/${uri.host}/o/${Uri.encodeComponent(object)}?alt=media');
  }

  Future<Map<String, String>> storageHeaders(
          FirebaseCoupleConfig config) async =>
      {
        'Authorization':
            'Firebase ${await account.idTokenFor(config.projectId)}',
      };

  Future<http.Response> response(
      String source, FirebaseCoupleConfig config) async {
    final uri = downloadUri(source, config);
    final response = await _client
        .get(uri, headers: await storageHeaders(config))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw const RochyAccountException(
          'No se pudo acceder al archivo con este perfil.');
    }
    return response;
  }

  Future<Uint8List> bytes(String source, FirebaseCoupleConfig config) async =>
      (await response(source, config)).bodyBytes;

  Future<ProtectedMediaPlayback> playback(
      String source, FirebaseCoupleConfig config) async {
    final uri = downloadUri(source, config);
    if (!kIsWeb) {
      return ProtectedMediaPlayback(
          uri.toString(), await storageHeaders(config), () {});
    }
    // Browser video/audio elements cannot send an Authorization header. Fetch
    // with the device identity, then expose only an ephemeral same-device blob.
    final data = await response(source, config);
    final url = createMediaObjectUrl(data.bodyBytes,
        data.headers['content-type'] ?? 'application/octet-stream');
    return ProtectedMediaPlayback(
        url, const {}, () => revokeMediaObjectUrl(url));
  }
}
