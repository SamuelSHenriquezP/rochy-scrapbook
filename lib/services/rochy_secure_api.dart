import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'rochy_account_service.dart';
import 'rochy_cloud_sync_service.dart';

Object firestoreValue(Object? value) {
  if (value == null) return {'nullValue': null};
  if (value is DateTime) {
    return {'timestampValue': value.toUtc().toIso8601String()};
  }
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': '$value'};
  if (value is num) return {'doubleValue': value};
  if (value is String) return {'stringValue': value};
  if (value is List) {
    return {
      'arrayValue': {'values': value.map(firestoreValue).toList()}
    };
  }
  if (value is Map) {
    return {
      'mapValue': {
        'fields': value.map((k, v) => MapEntry('$k', firestoreValue(v)))
      }
    };
  }
  throw ArgumentError('Unsupported Firestore value');
}

dynamic firestoreDecode(Map<String, dynamic> value) {
  if (value.containsKey('nullValue')) return null;
  if (value.containsKey('stringValue')) return value['stringValue'];
  if (value.containsKey('timestampValue')) return value['timestampValue'];
  if (value.containsKey('booleanValue')) return value['booleanValue'];
  if (value.containsKey('integerValue')) {
    return int.parse('${value['integerValue']}');
  }
  if (value.containsKey('doubleValue')) return value['doubleValue'];
  if (value.containsKey('arrayValue')) {
    return ((value['arrayValue'] as Map)['values'] as List? ?? [])
        .map((e) => firestoreDecode(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  return ((value['mapValue'] as Map?)?['fields'] as Map? ?? {}).map((k, v) =>
      MapEntry('$k', firestoreDecode(Map<String, dynamic>.from(v as Map))));
}

class SecureDocument {
  const SecureDocument(this.path, this.data, this.revision);
  final String path;
  final Map<String, dynamic> data;
  final String revision;
  factory SecureDocument.fromJson(Map<String, dynamic> json) => SecureDocument(
        (json['name'] as String).split('/documents/').last,
        (json['fields'] as Map? ?? {}).map((k, v) => MapEntry(
            '$k', firestoreDecode(Map<String, dynamic>.from(v as Map)))),
        json['updateTime'] as String? ?? '',
      );
}

class RochySecureApi {
  RochySecureApi(this.config, this.account, {http.Client? client})
      : client = client ?? account.httpClient;
  final FirebaseCoupleConfig config;
  final RochyAccountService account;
  final http.Client client;
  String get database => 'projects/${config.projectId}/databases/(default)';
  String documentName(String path) => '$database/documents/$path';
  Future<Map<String, String>> get headers async => {
        'Authorization': 'Bearer ${await account.idTokenFor(config.projectId)}',
        'Content-Type': 'application/json',
      };
  Uri _uri(String path, Map<String, String>? query) => Uri.https(
      'firestore.googleapis.com',
      '/v1/${documentName(path)}',
      {'key': config.apiKey, ...?query});

  Future<http.Response> _send(String method, String path,
      {Object? body, Map<String, String>? query}) async {
    final request = http.Request(method, _uri(path, query));
    request.headers.addAll(await headers);
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await client.send(request))
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const FirebaseSyncException(
          'Este dispositivo no tiene permiso para acceder a esos datos.');
    }
    if (response.statusCode == 409 || response.statusCode == 412) {
      throw const FirebaseSyncException(
          'Hubo cambios mientras sincronizabas. Se reintentará automáticamente.');
    }
    if (response.statusCode >= 400 && response.statusCode != 404) {
      throw FirebaseSyncException(
          'No se pudo completar la sincronización (${response.statusCode}).');
    }
    return response;
  }

  Future<SecureDocument?> read(String path) async {
    final response = await _send('GET', path);
    return response.statusCode == 404
        ? null
        : SecureDocument.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<SecureDocument>> list(String collection) async {
    final result = <SecureDocument>[];
    String? cursor;
    do {
      final response = await _send('GET', collection,
          query: {'pageSize': '100', if (cursor != null) 'pageToken': cursor});
      if (response.statusCode == 404) return result;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      result.addAll((json['documents'] as List? ?? []).map(
          (e) => SecureDocument.fromJson(Map<String, dynamic>.from(e as Map))));
      cursor = json['nextPageToken'] as String?;
    } while (cursor != null && cursor.isNotEmpty);
    return result;
  }

  Future<SecureDocument> write(String path, Map<String, dynamic> data,
      {String? revision, bool create = false}) async {
    final response = await _send('PATCH', path, body: {
      'fields': data.map((k, v) => MapEntry(k, firestoreValue(v)))
    }, query: {
      if (create) 'currentDocument.exists': 'false',
      if (revision != null && revision.isNotEmpty)
        'currentDocument.updateTime': revision,
    });
    if (response.statusCode == 404) {
      throw const FirebaseSyncException('El cuaderno ya no está disponible.');
    }
    return SecureDocument.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> delete(SecureDocument document) async {
    await _send('DELETE', document.path,
        query: {'currentDocument.updateTime': document.revision});
  }

  Future<String?> restoreBinding() async {
    await account.initialize(
        projectId: config.projectId, apiKey: config.apiKey);
    final binding = await read('profileDevices/${account.uid}');
    if (binding == null) return null;
    final profile = binding.data['profileId'] as String;
    await account.bindVerifiedProfile(profile);
    return profile;
  }

  Future<void> linkDevice(String profile, String invitation) async {
    await account.initialize(
        projectId: config.projectId, apiKey: config.apiKey);
    final token = invitation.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{32,128}$').hasMatch(token)) {
      throw const FirebaseSyncException(
          'El código de vinculación no es válido.');
    }
    final existing = await restoreBinding();
    if (existing != null) {
      if (existing != profile) {
        throw const FirebaseSyncException(
            'Este dispositivo ya pertenece al otro perfil.');
      }
      return;
    }
    final recovery = await read('recoveryKeys/$token');
    if (recovery != null) {
      final profiles =
          List<String>.from(recovery.data['profiles'] as List? ?? []);
      if (!profiles.contains(profile)) {
        throw const FirebaseSyncException(
            'El código no corresponde a este perfil.');
      }
      await write(
          'profileDevices/${account.uid}',
          {
            'profileId': profile,
            'invitationId': token,
          },
          create: true);
      await restoreBinding();
      return;
    }
    final invite = await read('deviceInvites/$token');
    if (invite == null ||
        invite.data['profileId'] != profile ||
        invite.data['usedBy'] != '') {
      throw const FirebaseSyncException(
          'El código no corresponde a este perfil o ya se utilizó.');
    }
    final request = http.Request(
        'POST',
        Uri.https('firestore.googleapis.com', '/v1/$database/documents:commit',
            {'key': config.apiKey}));
    request.headers.addAll(await headers);
    request.body = jsonEncode({
      'writes': [
        {
          'update': {
            'name': documentName('profileDevices/${account.uid}'),
            'fields': {
              'profileId': firestoreValue(profile),
              'invitationId': firestoreValue(token)
            }
          },
          'currentDocument': {'exists': false}
        },
        {
          'update': {
            'name': documentName('deviceInvites/$token'),
            'fields': {'usedBy': firestoreValue(account.uid)}
          },
          'updateMask': {
            'fieldPaths': ['usedBy']
          },
          'currentDocument': {'updateTime': invite.revision}
        },
      ]
    });
    final response = await http.Response.fromStream(await client.send(request))
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw const FirebaseSyncException(
          'No se pudo vincular el dispositivo. El código puede haber caducado o ya estar en uso.');
    }
    await restoreBinding();
  }

  Future<String?> accessCode() async {
    final role = await restoreBinding();
    if (role == null) {
      throw const FirebaseSyncException('Vincula primero este dispositivo.');
    }
    return (await read('profileAccess/$role'))?.data['code'] as String?;
  }

  Future<String> changeAccessCode() async {
    final role = await restoreBinding();
    if (role == null) {
      throw const FirebaseSyncException('Vincula primero este dispositivo.');
    }
    final previous = await read('profileAccess/$role');
    final oldCode = previous?.data['code'] as String?;
    final code =
        base64UrlEncode(List.generate(32, (_) => Random.secure().nextInt(256)))
            .replaceAll('=', '');
    final request = http.Request(
        'POST',
        Uri.https('firestore.googleapis.com', '/v1/$database/documents:commit',
            {'key': config.apiKey}));
    request.headers.addAll(await headers);
    request.body = jsonEncode({
      'writes': [
        {
          'update': {
            'name': documentName('recoveryKeys/$code'),
            'fields': {
              'profiles': firestoreValue([role])
            }
          },
          'currentDocument': {'exists': false}
        },
        {
          'update': {
            'name': documentName('profileAccess/$role'),
            'fields': {
              'code': firestoreValue(code),
              'updatedAt': firestoreValue(DateTime.now().toUtc())
            }
          },
          'currentDocument': previous == null
              ? {'exists': false}
              : {'updateTime': previous.revision}
        },
        if (oldCode != null) {'delete': documentName('recoveryKeys/$oldCode')},
      ]
    });
    final response = await http.Response.fromStream(await client.send(request))
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw const FirebaseSyncException(
          'No se pudo cambiar el código. Reintenta cuando tengas conexión.');
    }
    return code;
  }

  Future<String> createInvitation() async {
    final profile = await restoreBinding();
    if (profile == null) {
      throw const FirebaseSyncException('Vincula primero este dispositivo.');
    }
    final random = Random.secure();
    final token = base64UrlEncode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    await write(
        'deviceInvites/$token',
        {
          'profileId': profile,
          'usedBy': '',
          'expiresAt': DateTime.now().toUtc().add(const Duration(hours: 23))
        },
        create: true);
    return token;
  }
}
