import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weyonje/core/auth/auth_repository.dart';
import 'package:weyonje/core/auth/session_credentials.dart';
import 'package:weyonje/core/auth/session_store.dart';
import 'package:weyonje/core/config/app_config.dart';

class MemorySessionStore implements SessionStore {
  MemorySessionStore([this.value]);
  SessionCredentials? value;
  int clears = 0;
  int writes = 0;

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }

  @override
  Future<SessionCredentials?> read() async => value;

  @override
  Future<void> write(SessionCredentials credentials) async {
    writes++;
    value = credentials;
  }
}

Map<String, Object> credentialsJson({required String suffix}) => {
  'accessToken': 'access-$suffix',
  'refreshToken': 'refresh-$suffix',
  'accessTokenExpiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
  'refreshTokenExpiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(days: 1))
      .toIso8601String(),
};

void main() {
  const config = AppConfig(apiBaseUrl: 'https://api.example.test');

  test('rejects missing, insecure, and placeholder API addresses', () {
    expect(const AppConfig(apiBaseUrl: '').validate(), isNotNull);
    expect(
      const AppConfig(apiBaseUrl: 'http://api.example.test').validate(),
      isNotNull,
    );
    expect(
      const AppConfig(apiBaseUrl: 'https://api.example.invalid').validate(),
      isNotNull,
    );
    expect(config.validate(), isNull);
  });

  test(
    'native sign-in stores credentials then resolves the current actor',
    () async {
      final store = MemorySessionStore();
      final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.path == '/v1/auth/sign-in') {
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: credentialsJson(suffix: '1'),
                ),
              );
            } else {
              expect(request.headers['Authorization'], 'Bearer access-1');
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {'actorType': 'CLIENT', 'access': 'ELIGIBLE'},
                ),
              );
            }
          },
        ),
      );
      final repository = NativeAuthRepository(config, store, dio);
      final outcome = await repository.signInWithEmail(
        'account@example.test',
        'not-a-real-password',
        CancelToken(),
      );
      expect(outcome, isA<ResolvedSession>());
      expect(store.writes, 1);
    },
  );

  test('maps sign-in authentication and throttling failures safely', () async {
    Future<AuthOutcome> outcomeFor(int statusCode) async {
      final store = MemorySessionStore();
      final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.reject(
            DioException.badResponse(
              statusCode: statusCode,
              requestOptions: request,
              response: Response(
                requestOptions: request,
                statusCode: statusCode,
                data: {'code': 'safe-error'},
              ),
            ),
          ),
        ),
      );
      return NativeAuthRepository(config, store, dio).signInWithEmail(
        'account@example.test',
        'not-a-real-password',
        CancelToken(),
      );
    }

    await expectLater(outcomeFor(401), completion(isA<InvalidSession>()));
    await expectLater(
      outcomeFor(429),
      completion(isA<RateLimitedAuthFailure>()),
    );
  });

  test('preserves recoverable credentials during a network failure', () async {
    final stored = SessionCredentials.fromJson(credentialsJson(suffix: '1'));
    final store = MemorySessionStore(stored);
    final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.reject(
          DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          ),
        ),
      ),
    );

    final outcome = await NativeAuthRepository(
      config,
      store,
      dio,
    ).resolveStoredSession(CancelToken());
    expect(outcome, isA<TransientAuthFailure>());
    expect(store.value, same(stored));
    expect(store.clears, 0);
  });

  test('clears credentials after an unrecoverable refresh rejection', () async {
    final expired = SessionCredentials(
      accessToken: 'access-old',
      refreshToken: 'refresh-old',
      accessTokenExpiresAt: DateTime.now().toUtc().subtract(
        const Duration(minutes: 1),
      ),
      refreshTokenExpiresAt: DateTime.now().toUtc().add(
        const Duration(days: 1),
      ),
    );
    final store = MemorySessionStore(expired);
    final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.reject(
          DioException.badResponse(
            statusCode: 401,
            requestOptions: request,
            response: Response(requestOptions: request, statusCode: 401),
          ),
        ),
      ),
    );

    final outcome = await NativeAuthRepository(
      config,
      store,
      dio,
    ).resolveStoredSession(CancelToken());
    expect(outcome, isA<InvalidSession>());
    expect(store.value, isNull);
    expect(store.clears, 1);
  });

  test('coalesces concurrent refresh attempts', () async {
    final expired = SessionCredentials(
      accessToken: 'access-old',
      refreshToken: 'refresh-old',
      accessTokenExpiresAt: DateTime.now().toUtc().subtract(
        const Duration(minutes: 1),
      ),
      refreshTokenExpiresAt: DateTime.now().toUtc().add(
        const Duration(days: 1),
      ),
    );
    final store = MemorySessionStore(expired);
    final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));
    final releaseRefresh = Completer<void>();
    var refreshCalls = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          if (request.path == '/v1/auth/refresh') {
            refreshCalls++;
            await releaseRefresh.future;
            handler.resolve(
              Response(
                requestOptions: request,
                data: credentialsJson(suffix: 'new'),
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: request,
                data: {'actorType': 'CLIENT', 'access': 'ELIGIBLE'},
              ),
            );
          }
        },
      ),
    );
    final repository = NativeAuthRepository(config, store, dio);
    final first = repository.resolveStoredSession(CancelToken());
    final second = repository.resolveStoredSession(CancelToken());
    releaseRefresh.complete();

    final outcomes = await Future.wait([first, second]);
    expect(outcomes, everyElement(isA<ResolvedSession>()));
    expect(refreshCalls, 1);
    expect(store.value?.refreshToken, 'refresh-new');
  });

  test(
    'expired access performs one rotation and atomically replaces storage',
    () async {
      final old = SessionCredentials(
        accessToken: 'access-old',
        refreshToken: 'refresh-old',
        accessTokenExpiresAt: DateTime.now().toUtc().subtract(
          const Duration(minutes: 1),
        ),
        refreshTokenExpiresAt: DateTime.now().toUtc().add(
          const Duration(days: 1),
        ),
      );
      final store = MemorySessionStore(old);
      final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));
      var refreshCalls = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.path == '/v1/auth/refresh') {
              refreshCalls++;
              expect(request.data, {'refreshToken': 'refresh-old'});
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: credentialsJson(suffix: 'new'),
                ),
              );
            } else {
              expect(request.headers['Authorization'], 'Bearer access-new');
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {'actorType': 'CLIENT', 'access': 'ELIGIBLE'},
                ),
              );
            }
          },
        ),
      );
      final outcome = await NativeAuthRepository(
        config,
        store,
        dio,
      ).resolveStoredSession(CancelToken());
      expect(outcome, isA<ResolvedSession>());
      expect(refreshCalls, 1);
      expect(store.value?.refreshToken, 'refresh-new');
    },
  );

  test(
    'sign-out clears local credentials when server revocation fails',
    () async {
      final store = MemorySessionStore(
        SessionCredentials.fromJson(credentialsJson(suffix: '1')),
      );
      final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.reject(
            DioException(
              requestOptions: request,
              type: DioExceptionType.connectionError,
            ),
          ),
        ),
      );
      await NativeAuthRepository(config, store, dio).signOut();
      expect(store.value, isNull);
      expect(store.clears, 1);
    },
  );

  test('treats stored session fields as untrusted', () {
    expect(
      () => SessionCredentials.fromJson({
        'accessToken': '',
        'refreshToken': 'value',
        'accessTokenExpiresAt': 'not-a-date',
        'refreshTokenExpiresAt': 'not-a-date',
      }),
      throwsFormatException,
    );
  });
}
