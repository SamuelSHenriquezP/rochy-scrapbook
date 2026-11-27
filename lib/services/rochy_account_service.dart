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
    final stored = await _storage.read(key: _storageKey);
    if (stored != null) {
      final data = jsonDecode(stored) as Map<String, dynamic>;
      _uid = data['uid'] as String;
      _refreshToken = data['refreshToken'] as String;
      _authorId = data['profileId'] as String?;
      try {
        await _refresh();
        return;
      } on http.ClientException {
        if (_authorId != null) return;
        rethrow;
      } on TimeoutException {
        if (_authorId != null) return;
        rethrow;
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

  @override
  void dispose() {
    _generation++;
    _client.close();
    super.dispose();
  }
}
