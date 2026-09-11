import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weyonje/core/auth/auth_repository.dart';
import 'package:weyonje/core/config/app_config.dart';
import 'package:weyonje/core/auth/registration_models.dart';
import 'auth_repository_test.dart' show MemorySessionStore, credentialsJson;

void main() {
  const config = AppConfig(apiBaseUrl: 'https://api.example.test');
  test(
    'Provider endpoints remain isolated and never interpret Client registration outcome',
    () async {
      final paths = <String>[];
      final store = MemorySessionStore();
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              paths.add(request.path);
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {'outcome': 'REGISTRATION_REQUIRED'},
                ),
              );
            },
          ),
        );
      final repository = NativeAuthRepository(config, store, dio);
      expect(
        await repository.requestPhoneSignInCode(
          '0700000123',
          CancelToken(),
          actor: PhoneSignInActor.serviceProvider,
        ),
        isA<ChallengeFailure>(),
      );
      expect(
        await repository.resendPhoneSignInCode(
          'challenge',
          CancelToken(),
          actor: PhoneSignInActor.serviceProvider,
        ),
        isA<ChallengeFailure>(),
      );
      await repository.verifyPhoneSignInCode(
        'challenge',
        '001234',
        CancelToken(),
        actor: PhoneSignInActor.serviceProvider,
      );
      expect(paths, [
        '/v1/auth/provider-code/request',
        '/v1/auth/provider-code/resend',
        '/v1/auth/provider-code/verify',
      ]);
      expect(store.writes, 0);
    },
  );
  test('parses registration outcome without writing a session', () async {
    final store = MemorySessionStore();
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.resolve(
            Response(
              requestOptions: request,
              data: {'outcome': 'REGISTRATION_REQUIRED'},
            ),
          ),
        ),
      );
    final repository = NativeAuthRepository(config, store, dio);
    expect(
      await repository.requestPhoneSignInCode('0700000123', CancelToken()),
      isA<RegistrationRequired>(),
    );
    expect(store.writes, 0);
    expect(
      await repository.resendPhoneSignInCode('challenge', CancelToken()),
      isA<ChallengeFailure>(),
    );
  });
  for (final category in ['OTP_HOURLY', 'OTP_COOLDOWN', 'CLIENT_REQUEST']) {
    test('preserves server retry timing for $category', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) => handler.reject(
              DioException(
                requestOptions: request,
                response: Response(
                  requestOptions: request,
                  statusCode: category == 'OTP_COOLDOWN' ? 400 : 429,
                  data: {
                    'limitCategory': category,
                    'retryAt': '2026-09-10T12:00:00Z',
                  },
                ),
              ),
            ),
          ),
        );
      final outcome =
          await NativeAuthRepository(
                config,
                MemorySessionStore(),
                dio,
              ).requestPhoneSignInCode('0700000123', CancelToken())
              as ChallengeFailure;
      expect(outcome.retryAt, DateTime.utc(2026, 9, 10, 12));
      expect(outcome.rateLimited, isTrue);
      expect(outcome.limitCategory, isNotNull);
      expect(outcome.message, contains('Try again at'));
    });
  }
  for (final registration in [true, false]) {
    for (final legacy in [
      '001234',
      123456,
      {'unexpected': true},
    ]) {
      test(
        'challenge ignores legacy extra data with no session write: $registration $legacy',
        () async {
          final store = MemorySessionStore();
          final dio = Dio();
          final paths = <String>[];
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                paths.add(request.path);
                handler.resolve(
                  Response(
                    requestOptions: request,
                    data: {
                      'challengeId': 'challenge',
                      'maskedPhone': '+256 •••••• 123',
                      'expiresAt': DateTime.now()
                          .toUtc()
                          .add(const Duration(minutes: 10))
                          .toIso8601String(),
                      'resendAvailableAt': DateTime.now()
                          .toUtc()
                          .toIso8601String(),
                      'deliveryStatus': 'SENT',
                      'developmentVerificationCode': legacy,
                    },
                  ),
                );
              },
            ),
          );
          final repository = NativeAuthRepository(config, store, dio);
          final outcome = registration
              ? await repository.registerClient(
                  const ClientRegistrationRequest(
                    clientType: ClientType.individual,
                    phoneNumber: '0700000123',
                    firstName: 'Test',
                    lastName: 'Client',
                  ),
                  CancelToken(),
                )
              : await repository.requestPhoneSignInCode(
                  '0700000123',
                  CancelToken(),
                );
          expect(outcome, isA<ChallengeCreated>());
          expect(paths, [
            registration
                ? '/v1/registrations/clients'
                : '/v1/auth/client-code/request',
          ]);
          expect(store.writes, 0);
          expect(store.value, isNull);
        },
      );
    }
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
            : await repository.verifyPhoneSignInCode(
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
        ).verifyPhoneSignInCode('challenge', '001234', CancelToken());
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
        await repository.verifyPhoneSignInCode(
          'challenge',
          '001234',
          CancelToken(),
        ),
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
