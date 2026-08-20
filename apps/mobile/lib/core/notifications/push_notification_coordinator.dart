import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth_providers.dart';
import '../auth/session_store.dart';
import '../config/app_config.dart';

class PushNotificationCoordinator {
  PushNotificationCoordinator(
    this._config,
    this._dio,
    this._sessions,
    this._storage,
  );
  final AppConfig _config;
  final Dio _dio;
  final SessionStore _sessions;
  final FlutterSecureStorage _storage;
  final _routes = StreamController<String>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openSubscription;
  bool _started = false;
  String? _installationId;

  Stream<String> get routes => _routes.stream;

  Future<void> start() async {
    if (_started || !_config.fcmEnabled) return;
    _started = true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final installationId = await _installation();
      final token = await messaging.getToken();
      if (token != null) await _register(installationId, token);
      _tokenSubscription = messaging.onTokenRefresh.listen(
        (token) => _register(installationId, token),
      );
      _openSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_route);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _route(initial);
    } catch (_) {
      _started = false;
      // Missing Firebase resources leave in-app REST reconciliation available.
    }
  }

  Future<void> disable() async {
    if (!_config.fcmEnabled) return;
    final installationId =
        _installationId ?? await _storage.read(key: 'push.installation.v1');
    final session = await _sessions.read();
    if (installationId != null && session != null) {
      try {
        await _dio.delete<Object?>(
          '/v1/notification-devices/$installationId',
          options: Options(
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          ),
        );
      } catch (_) {
        // Local token deletion still prevents this installation from receiving.
      }
    }
    await _tokenSubscription?.cancel();
    await _openSubscription?.cancel();
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
    _started = false;
  }

  Future<String> _installation() async {
    final existing = await _storage.read(key: 'push.installation.v1');
    if (existing != null) return _installationId = existing;
    final created = const Uuid().v4();
    await _storage.write(key: 'push.installation.v1', value: created);
    return _installationId = created;
  }

  Future<void> _register(String installationId, String token) async {
    final session = await _sessions.read();
    if (session == null) return;
    await _dio.post<Object?>(
      '/v1/notification-devices',
      data: {
        'installationId': installationId,
        'token': token,
        'platform': 'ANDROID',
        'environment': _config.environment,
      },
      options: Options(
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      ),
    );
  }

  void _route(RemoteMessage message) {
    // Push is a hint. Always reconcile the authoritative notification list.
    _routes.add('/notifications');
  }
}

final pushNotificationCoordinatorProvider =
    Provider<PushNotificationCoordinator>((ref) {
      final coordinator = PushNotificationCoordinator(
        ref.watch(appConfigProvider),
        ref.watch(dioProvider),
        ref.watch(sessionStoreProvider),
        const FlutterSecureStorage(aOptions: AndroidOptions()),
      );
      ref.onDispose(coordinator.disable);
      return coordinator;
    });
