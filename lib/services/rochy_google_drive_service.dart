import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

final rochyGoogleDriveServiceProvider = Provider<RochyGoogleDriveService>((ref) {
  return RochyGoogleDriveService();
});

class DriveBackupEntry {
  const DriveBackupEntry({
    required this.id,
    required this.name,
    required this.sizeBytes,
    this.createdTime,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final DateTime? createdTime;
}

class GoogleDriveBackupException implements Exception {
  const GoogleDriveBackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Servicio para respaldar, listar y restaurar archivos `.rochy.zip`
/// directamente en la carpeta `Mi unidad / Rochy Backups` de Google Drive.
class RochyGoogleDriveService {
  RochyGoogleDriveService({http.Client? client})
      : _client = client ?? http.Client();

  static const String _backupFolderName = 'Rochy Backups';
  static const String _driveFilesEndpoint =
      'https://www.googleapis.com/drive/v3/files';
  static const String _driveUploadEndpoint =
      'https://www.googleapis.com/upload/drive/v3/files';

  final http.Client _client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const <String>['https://www.googleapis.com/auth/drive.file'],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> restorePreviousSession() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (_) {
      return _googleSignIn.currentUser;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      final raw = '${e.code} ${e.message ?? ''}';
      if (raw.contains('ApiException: 10') ||
          raw.contains('DEVELOPER_ERROR') ||
          raw.contains('sign_in_failed')) {
        throw const GoogleDriveBackupException(
          'Falta registrar la huella SHA-1 y los correos de prueba OAuth de Google Drive en Google Cloud Console.',
        );
      }
      throw GoogleDriveBackupException(
        'No se pudo iniciar sesión en Google Drive (${e.message ?? e.code}).',
      );
    } catch (e) {
      throw GoogleDriveBackupException(
        'No se pudo conectar con Google Drive ($e).',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<Map<String, String>> _requireAuthHeaders() async {
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    if (account == null) {
      throw const GoogleDriveBackupException(
        'Conecta tu cuenta de Google Drive primero.',
      );
    }
    final headers = await account.authHeaders;
    if (headers['Authorization'] == null || headers['Authorization']!.isEmpty) {
      throw const GoogleDriveBackupException(
        'Tu sesión de Google Drive expiró. Vuelve a conectarla.',
      );
    }
    return Map<String, String>.of(headers);
  }

  Future<String> _ensureBackupFolder(Map<String, String> authHeaders) async {
    const query =
        "name = '$_backupFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final searchUri = Uri.parse(_driveFilesEndpoint).replace(
      queryParameters: const <String, String>{
        'q': query,
        'spaces': 'drive',
        'fields': 'files(id, name)',
      },
    );

    final searchResp = await _client
        .get(searchUri, headers: authHeaders)
        .timeout(const Duration(seconds: 20));
    _throwIfDriveError(searchResp, 'buscar carpeta en Drive');

    final decoded = jsonDecode(searchResp.body) as Map<String, dynamic>? ?? const {};
    final files = decoded['files'] as List<dynamic>? ?? const <dynamic>[];
    if (files.isNotEmpty && files.first is Map) {
      final id = (files.first as Map)['id'] as String?;
      if (id != null && id.isNotEmpty) return id;
    }

    final createResp = await _client
        .post(
          Uri.parse(_driveFilesEndpoint).replace(
            queryParameters: const <String, String>{'fields': 'id'},
          ),
          headers: <String, String>{
            ...authHeaders,
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(const <String, dynamic>{
            'name': _backupFolderName,
            'mimeType': 'application/vnd.google-apps.folder',
          }),
        )
        .timeout(const Duration(seconds: 20));
    _throwIfDriveError(createResp, 'crear carpeta Rochy Backups');

    final created = jsonDecode(createResp.body) as Map<String, dynamic>? ?? const {};
    final newId = created['id'] as String? ?? '';
    if (newId.isEmpty) {
      throw const GoogleDriveBackupException(
        'No se recibió el ID de la carpeta en Google Drive.',
      );
    }
    return newId;
  }

  Future<DriveBackupEntry> uploadBackupZip(File zipFile) async {
    if (!await zipFile.exists()) {
      throw const GoogleDriveBackupException('No se encontró el archivo .zip.');
    }
    final authHeaders = await _requireAuthHeaders();
    final folderId = await _ensureBackupFolder(authHeaders);

    final parts = zipFile.path
        .split(RegExp(r'[/\\]'))
        .where((s) => s.isNotEmpty)
        .toList();
    final fileName = parts.isNotEmpty ? parts.last : 'Rochy_Respaldo.rochy.zip';
    final fileBytes = await zipFile.readAsBytes();

    final boundary = 'rochy_drive_${DateTime.now().microsecondsSinceEpoch}';
    final metadataJson = jsonEncode(<String, dynamic>{
      'name': fileName,
      'parents': <String>[folderId],
      'mimeType': 'application/zip',
    });

    final builder = BytesBuilder(copy: false)
      ..add(utf8.encode('--$boundary\r\n'))
      ..add(utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'))
      ..add(utf8.encode(metadataJson))
      ..add(utf8.encode('\r\n--$boundary\r\n'))
      ..add(utf8.encode('Content-Type: application/zip\r\n\r\n'))
      ..add(fileBytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));

    final uploadUri = Uri.parse(_driveUploadEndpoint).replace(
      queryParameters: const <String, String>{
        'uploadType': 'multipart',
        'fields': 'id, name, size, createdTime',
      },
    );

    final resp = await _client
        .post(
          uploadUri,
          headers: <String, String>{
            ...authHeaders,
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: builder.takeBytes(),
        )
        .timeout(const Duration(seconds: 90));
    _throwIfDriveError(resp, 'subir el respaldo a Google Drive');

    final map = jsonDecode(resp.body) as Map<String, dynamic>? ?? const {};
    return _entryFromJson(map, fallbackSize: fileBytes.length, fallbackName: fileName);
  }

  Future<List<DriveBackupEntry>> listBackups() async {
    final authHeaders = await _requireAuthHeaders();
    final folderId = await _ensureBackupFolder(authHeaders);

    final query =
        "'$folderId' in parents and trashed = false and mimeType != 'application/vnd.google-apps.folder'";
    final uri = Uri.parse(_driveFilesEndpoint).replace(
      queryParameters: <String, String>{
        'q': query,
        'orderBy': 'createdTime desc',
        'pageSize': '20',
        'spaces': 'drive',
        'fields': 'files(id, name, size, createdTime)',
      },
    );

    final resp = await _client
        .get(uri, headers: authHeaders)
        .timeout(const Duration(seconds: 20));
    _throwIfDriveError(resp, 'listar respaldos en Google Drive');

    final map = jsonDecode(resp.body) as Map<String, dynamic>? ?? const {};
    final files = map['files'] as List<dynamic>? ?? const <dynamic>[];
    return files
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => _entryFromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<File> downloadBackupZip(DriveBackupEntry entry) async {
    final authHeaders = await _requireAuthHeaders();
    final uri = Uri.parse('$_driveFilesEndpoint/${entry.id}').replace(
      queryParameters: const <String, String>{'alt': 'media'},
    );

    final resp = await _client
        .get(uri, headers: authHeaders)
        .timeout(const Duration(seconds: 90));
    _throwIfDriveError(resp, 'descargar respaldo desde Google Drive');

    final tempDir = await getTemporaryDirectory();
    final safeId = entry.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final sep = Platform.pathSeparator;
    final base = tempDir.path.endsWith(sep) ? tempDir.path : '${tempDir.path}$sep';
    final destFile = File('${base}drive_$safeId.rochy.zip');
    await destFile.writeAsBytes(resp.bodyBytes, flush: true);
    return destFile;
  }

  Future<void> deleteBackup(String fileId) async {
    final authHeaders = await _requireAuthHeaders();
    final uri = Uri.parse('$_driveFilesEndpoint/$fileId');
    final resp = await _client
        .delete(uri, headers: authHeaders)
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      _throwIfDriveError(resp, 'eliminar respaldo en Google Drive');
    }
  }

  DriveBackupEntry _entryFromJson(
    Map<String, dynamic> map, {
    int fallbackSize = 0,
    String fallbackName = 'Respaldo.rochy.zip',
  }) {
    final rawSize = map['size'];
    final parsedSize = rawSize is num
        ? rawSize.toInt()
        : int.tryParse(rawSize?.toString() ?? '') ?? fallbackSize;
    final rawTime = map['createdTime'] as String?;
    return DriveBackupEntry(
      id: map['id'] as String? ?? '',
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : fallbackName,
      sizeBytes: parsedSize,
      createdTime: rawTime != null ? DateTime.tryParse(rawTime)?.toLocal() : null,
    );
  }

  void _throwIfDriveError(http.Response resp, String actionLabel) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    if (resp.statusCode == 401) {
      throw const GoogleDriveBackupException(
        'La autorización de Google Drive caducó. Desconecta y vuelve a conectar tu cuenta.',
      );
    }
    if (resp.statusCode == 403) {
      throw const GoogleDriveBackupException(
        'Google Drive rechazó la operación (403). Verifica que la Google Drive API esté habilitada en Google Cloud Console.',
      );
    }
    throw GoogleDriveBackupException(
      'Error al $actionLabel (código ${resp.statusCode}).',
    );
  }
}
