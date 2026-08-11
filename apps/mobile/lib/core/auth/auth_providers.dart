import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import 'auth_repository.dart';
import 'session_store.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(
    const FlutterSecureStorage(aOptions: AndroidOptions()),
  ),
);

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  return Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
    ),
  );
});

final flutterAppAuthProvider = Provider<FlutterAppAuth>(
  (ref) => const FlutterAppAuth(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => OidcAuthRepository(
    ref.watch(appConfigProvider),
    ref.watch(sessionStoreProvider),
    ref.watch(dioProvider),
    ref.watch(flutterAppAuthProvider),
  ),
);
