import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

final rochyAccountProvider =
    ChangeNotifierProvider<RochyAccountService>((ref) => RochyAccountService());

class RochyAccountException implements Exception {
  const RochyAccountException(this.message);
  final String message;
  @override
  String toString() => message;
}

// An invitation binds a Firebase device identity to Sam or Rochy once.
// Selecting a name does not grant access; emails and passwords are not used.
class RochyAccountService extends ChangeNotifier {
  RochyAccountService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;
  http.Client get httpClient => _client;
  String? _uid, _projectId, _apiKey, _idToken, _refreshToken, _authorId;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<String>? _refreshing;
  Future<void>? _initializing;
  int _generation = 0;

  String? get uid => _uid;
  String? get authorId => _authorId;
  bool get isLinked => _uid != null && _authorId != null;
  String get _storageKey => 'rochy_device_identity_$_projectId';

  Future<void> initialize(
      {required String projectId, required String apiKey}) async {
    if (_projectId == projectId && _uid != null) return;
    if (_initializing != null) return _initializing;
    final work = _initialize(projectId, apiKey);
    _initializing = work;
    try {
      await work;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize(String projectId, String apiKey) async {
    _projectId = projectId;
    _apiKey = apiKey;
    _generation++;
    _uid = _idToken = _refreshToken = _authorId = null;
    _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
    final stored = await _storage.read(key: _storageKey);
    if (stored != null) {
      try {
        final data = jsonDecode(stored);
        if (data is! Map ||
            data['uid'] is! String ||
            (data['uid'] as String).isEmpty ||
            data['refreshToken'] is! String ||
            (data['refreshToken'] as String).isEmpty ||
            (data['profileId'] != null &&
                !{'samuel', 'rochy'}.contains(data['profileId']))) {
          throw const FormatException('Invalid device identity cache');
        }
        _uid = data['uid'] as String;
        _refreshToken = data['refreshToken'] as String;
        _authorId = data['profileId'] as String?;
      } on FormatException {
        await _forgetIdentity();
      }
    }
    if (_uid != null) {
      try {
        await _refresh();
        return;
      } on http.ClientException {
        if (_authorId != null) return;
        rethrow;
      } on TimeoutException {
        if (_authorId != null) return;
        rethrow;
      } on RochyAccountException {
        // An invalid refresh token was cleared; create a fresh identity so the
        // permanent profile code can recover access. Never delete local books.
        if (_uid != null) rethrow;
      }
    }
    final response = await _client
        .post(
          Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:signUp',
              {'key': apiKey}),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'returnSecureToken': true}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      if (response.statusCode >= 500 || response.statusCode == 429) {
        throw http.ClientException('Firebase temporarily unavailable');
      }
      throw const RochyAccountException(
          'No se pudo reconocer este dispositivo. Revisa la conexión y la configuración de Firebase.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _uid = data['localId'] as String;
    _idToken = data['idToken'] as String;
    _refreshToken = data['refreshToken'] as String;
    _authorId = null;
    _expiresAt = DateTime.now()
        .add(Duration(seconds: int.parse('${data['expiresIn']}')));
    await _save();
    notifyListeners();
  }

  Future<String> idTokenFor(String projectId) async {
    if (_uid == null || projectId != _projectId) {
      throw const RochyAccountException(
          'Vincula este dispositivo con Sam o Rochy para sincronizar.');
    }
    if (_idToken != null &&
        DateTime.now()
            .isBefore(_expiresAt.subtract(const Duration(minutes: 2)))) {
      return _idToken!;
    }
    if (_refreshing != null) return _refreshing!;
    final refresh = _refresh();
    _refreshing = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshing, refresh)) _refreshing = null;
    }
  }

  Future<String> _refresh() async {
    final generation = _generation;
    final response = await _client.post(
      Uri.https('securetoken.googleapis.com', '/v1/token', {'key': _apiKey!}),
      body: {'grant_type': 'refresh_token', 'refresh_token': _refreshToken!},
    ).timeout(const Duration(seconds: 20));
    if (generation != _generation) {
      throw const RochyAccountException('La sesión del dispositivo cambió.');
    }
    if (response.statusCode != 200) {
      if (response.statusCode >= 500 || response.statusCode == 429) {
        throw http.ClientException('Firebase temporarily unavailable');
      }
      String code = '';
      try {
        final error = jsonDecode(response.body);
        if (error is Map && error['error'] is Map) {
          code = '${(error['error'] as Map)['message'] ?? ''}';
        }
      } on FormatException {
        // Keep the normal session error for non-JSON responses.
      }
      if ({'USER_NOT_FOUND', 'INVALID_REFRESH_TOKEN', 'TOKEN_EXPIRED'}
          .contains(code)) {
        await _forgetIdentity();
      }
      throw const RochyAccountException(
          'Este dispositivo necesita volver a vincularse.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['user_id'] != _uid) {
      throw const RochyAccountException(
          'La identidad del dispositivo no coincide.');
    }
    _idToken = data['id_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    _expiresAt = DateTime.now()
        .add(Duration(seconds: int.parse('${data['expires_in']}')));
    await _save();
    return _idToken!;
  }

  // Call only after reading the server-protected profileDevices document.
  Future<void> bindVerifiedProfile(String profileId) async {
    if (_uid == null || !{'samuel', 'rochy'}.contains(profileId)) {
      throw const RochyAccountException(
          'El dispositivo no está autorizado para ese perfil.');
    }
    _authorId = profileId;
    await _save();
    notifyListeners();
  }

  Future<void> _save() => _storage.write(
      key: _storageKey,
      value: jsonEncode({
        'uid': _uid,
        'refreshToken': _refreshToken,
        'profileId': _authorId,
      }));

  Future<void> _forgetIdentity() async {
    _generation++;
    _uid = _idToken = _refreshToken = _authorId = null;
    _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
    await _storage.delete(key: _storageKey);
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _client.close();
    super.dispose();
  }
}
