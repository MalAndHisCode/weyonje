import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_credentials.dart';

abstract interface class SessionStore {
  Future<SessionCredentials?> read();
  Future<void> write(SessionCredentials credentials);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore(this._storage);

  static const _session = 'auth.session.v1';
  static const _legacyKeys = [
    'auth.access_token',
    'auth.refresh_token',
    'auth.id_token',
    'auth.access_token_expiration',
  ];

  final FlutterSecureStorage _storage;

  @override
  Future<SessionCredentials?> read() async {
    final encoded = await _storage.read(key: _session);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return SessionCredentials.fromJson(jsonDecode(encoded));
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(SessionCredentials credentials) async {
    await _storage.write(
      key: _session,
      value: jsonEncode(credentials.toJson()),
    );
    await _clearLegacyKeys();
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _session);
    await _clearLegacyKeys();
  }

  Future<void> _clearLegacyKeys() async {
    for (final key in _legacyKeys) {
      await _storage.delete(key: key);
    }
  }
}
