import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weyonje/core/auth/auth_repository.dart';
import 'package:weyonje/core/config/app_config.dart';
import 'auth_repository_test.dart' show MemorySessionStore, credentialsJson;

void main() {
  const config = AppConfig(apiBaseUrl: 'https://api.example.test');
  for (final registration in [true, false]) {
    test(
      'phone session storage and actor resolution use purpose $registration endpoint',
      () async {
        final store = MemorySessionStore();
        final paths = <String>[];
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              paths.add(request.path);
              if (request.path.endsWith('verify') ||
                  request.path.endsWith('verify-phone')) {
                expect(request.data, {
                  'challengeId': 'challenge',
                  'code': '001234',
                });
                handler.resolve(
                  Response(
                    requestOptions: request,
                    data: credentialsJson(suffix: 'otp'),
                  ),
                );
              } else {
                expect(store.writes, 1);
                expect(request.headers['Authorization'], 'Bearer access-otp');
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
        final outcome = registration
            ? await repository.verifyRegistration(
                'challenge',
                '001234',
                CancelToken(),
              )
            : await repository.verifyClientCode(
                'challenge',
                '001234',
                CancelToken(),
              );
        expect(outcome, isA<ResolvedSession>());
        expect(paths, [
          registration
              ? '/v1/registrations/verify-phone'
              : '/v1/auth/client-code/verify',
          '/v1/actors/me',
        ]);
      },
    );
  }
  for (final entry in [
    (401, 'AUTH_INVALID_VERIFICATION_CODE', CodeFailureKind.invalid),
    (401, 'AUTH_VERIFICATION_EXPIRED', CodeFailureKind.expired),
    (429, 'RATE_LIMITED', CodeFailureKind.exhausted),
  ]) {
    test(
      'phone verification maps ${entry.$2} without saving a session',
      () async {
        final store = MemorySessionStore();
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) => handler.reject(
              DioException.badResponse(
                statusCode: entry.$1,
                requestOptions: request,
                response: Response(
                  requestOptions: request,
                  statusCode: entry.$1,
                  data: {'code': entry.$2},
                ),
              ),
            ),
          ),
        );
        final outcome = await NativeAuthRepository(
          config,
          store,
          dio,
        ).verifyClientCode('challenge', '001234', CancelToken());
        expect((outcome as CodeVerificationFailure).kind, entry.$3);
        expect(store.writes, 0);
      },
    );
  }
  test(
    'saved phone session survives failed actor resolution and resumes without OTP replay',
    () async {
      final store = MemorySessionStore();
      final dio = Dio();
      int verifies = 0;
      bool offline = true;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.path.endsWith('verify')) {
              verifies++;
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: credentialsJson(suffix: 'otp'),
                ),
              );
            } else if (offline) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.connectionTimeout,
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
      expect(
        await repository.verifyClientCode('challenge', '001234', CancelToken()),
        isA<VerifiedSessionPending>(),
      );
      expect(store.value, isNotNull);
      offline = false;
      expect(
        await repository.resolveStoredSession(CancelToken()),
        isA<ResolvedSession>(),
      );
      expect(verifies, 1);
    },
  );
}
