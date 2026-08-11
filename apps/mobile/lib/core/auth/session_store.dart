import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_credentials.dart';

abstract interface class SessionStore {
  Future<SessionCredentials?> read();
  Future<void> write(SessionCredentials credentials);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore(this._storage);

  static const _accessToken = 'auth.access_token';
  static const _refreshToken = 'auth.refresh_token';
  static const _idToken = 'auth.id_token';
  static const _expiration = 'auth.access_token_expiration';

  final FlutterSecureStorage _storage;

  @override
  Future<SessionCredentials?> read() async {
    final accessToken = await _storage.read(key: _accessToken);
    if (accessToken == null || accessToken.isEmpty) return null;
    final expirationValue = await _storage.read(key: _expiration);
    return SessionCredentials(
      accessToken: accessToken,
      refreshToken: await _storage.read(key: _refreshToken),
      idToken: await _storage.read(key: _idToken),
      accessTokenExpiration: expirationValue == null
          ? null
          : DateTime.tryParse(expirationValue),
    );
  }

  @override
  Future<void> write(SessionCredentials credentials) async {
    await _storage.write(key: _accessToken, value: credentials.accessToken);
    await _writeOptional(_refreshToken, credentials.refreshToken);
    await _writeOptional(_idToken, credentials.idToken);
    await _writeOptional(
      _expiration,
      credentials.accessTokenExpiration?.toUtc().toIso8601String(),
    );
  }

  Future<void> _writeOptional(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);

  @override
  Future<void> clear() async {
    for (final key in [_accessToken, _refreshToken, _idToken, _expiration]) {
      await _storage.delete(key: key);
    }
  }
}
