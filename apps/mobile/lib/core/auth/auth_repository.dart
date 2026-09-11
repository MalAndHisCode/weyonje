import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'current_actor.dart';
import 'session_credentials.dart';
import 'session_store.dart';
import 'registration_models.dart';

sealed class AuthOutcome {
  const AuthOutcome();
}

class NoStoredSession extends AuthOutcome {
  const NoStoredSession();
}

class ResolvedSession extends AuthOutcome {
  const ResolvedSession(this.actor);
  final CurrentActor actor;
}

class InvalidSession extends AuthOutcome {
  const InvalidSession(this.message);
  final String message;
}

class TransientAuthFailure extends AuthOutcome {
  const TransientAuthFailure(this.message);
  final String message;
}

class RateLimitedAuthFailure extends AuthOutcome {
  const RateLimitedAuthFailure(this.message);
  final String message;
}

class DeniedSession extends AuthOutcome {
  const DeniedSession(this.message);
  final String message;
}

class CancelledSignIn extends AuthOutcome {
  const CancelledSignIn();
}

enum CodeFailureKind { invalid, expired, exhausted }

class CodeVerificationFailure extends AuthOutcome {
  const CodeVerificationFailure(this.kind, this.message);
  final CodeFailureKind kind;
  final String message;
}

/// Credentials were saved; retry actor resolution, never consume the OTP again.
class VerifiedSessionPending extends AuthOutcome {
  const VerifiedSessionPending(this.outcome);
  final AuthOutcome outcome;
}

abstract interface class AuthRepository {
  Future<AuthOutcome> resolveStoredSession(CancelToken cancelToken);
  Future<AuthOutcome> signInWithEmail(
    String email,
    String password,
    CancelToken cancelToken,
  );
  Future<ChallengeOutcome> requestPhoneSignInCode(
    String phoneNumber,
    CancelToken cancelToken, {
    PhoneSignInActor actor = PhoneSignInActor.client,
  });
  Future<AuthOutcome> verifyPhoneSignInCode(
    String challengeId,
    String code,
    CancelToken cancelToken, {
    PhoneSignInActor actor = PhoneSignInActor.client,
  });
  Future<ChallengeOutcome> resendPhoneSignInCode(
    String challengeId,
    CancelToken cancelToken, {
    PhoneSignInActor actor = PhoneSignInActor.client,
  });
  Future<ChallengeOutcome> registerClient(
    ClientRegistrationRequest request,
    CancelToken cancelToken,
  );
  Future<ChallengeOutcome> registerServiceProvider(
    ServiceProviderRegistrationRequest request,
    CancelToken cancelToken,
  );
  Future<AuthOutcome> verifyRegistration(
    String challengeId,
    String code,
    CancelToken cancelToken,
  );
  Future<ChallengeOutcome> resendRegistrationCode(
    String challengeId,
    CancelToken cancelToken,
  );
  Future<void> signOut();
}

class NativeAuthRepository implements AuthRepository {
  NativeAuthRepository(this._config, this._sessionStore, this._dio);

  final AppConfig _config;
  final SessionStore _sessionStore;
  final Dio _dio;
  Future<Object>? _refreshInFlight;
  int _sessionGeneration = 0;

  @override
  Future<AuthOutcome> resolveStoredSession(CancelToken cancelToken) async {
    final stored = await _sessionStore.read();
    if (stored == null) return const NoStoredSession();
    final configurationError = _config.validate();
    if (configurationError != null) {
      return TransientAuthFailure(configurationError);
    }
    if (!stored.refreshTokenExpiresAt.isAfter(DateTime.now().toUtc())) {
      await _sessionStore.clear();
      return const InvalidSession('Your session has expired. Sign in again.');
    }
    return _resolve(stored, cancelToken, allowRefresh: true);
  }

  @override
  Future<AuthOutcome> signInWithEmail(
    String email,
    String password,
    CancelToken cancelToken,
  ) async {
    _sessionGeneration++;
    _refreshInFlight = null;
    final configurationError = _config.validate();
    if (configurationError != null) {
      return TransientAuthFailure(configurationError);
    }
    try {
      final response = await _dio.post<Object?>(
        '/v1/auth/sign-in',
        data: {'email': email, 'password': password},
        cancelToken: cancelToken,
      );
      final credentials = SessionCredentials.fromJson(response.data);
      if (cancelToken.isCancelled) return const CancelledSignIn();
      await _sessionStore.write(credentials);
      return _resolve(credentials, cancelToken, allowRefresh: true);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return const CancelledSignIn();
      if (error.response?.statusCode == 401) {
        return const InvalidSession('Email or password is incorrect.');
      }
      if (error.response?.statusCode == 429) {
        return const RateLimitedAuthFailure(
          'Too many sign-in attempts. Wait briefly and try again.',
        );
      }
      if (error.response?.statusCode == 400) {
        return const InvalidSession(
          'Check your email and password, then try again.',
        );
      }
      return const TransientAuthFailure(
        'Weyonje could not sign you in. Check your connection and try again.',
      );
    } on FormatException {
      await _sessionStore.clear();
      return const InvalidSession(
        'Sign-in returned an invalid session. Try again.',
      );
    } catch (_) {
      return const TransientAuthFailure(
        'Weyonje could not sign you in. Check your connection and try again.',
      );
    }
  }

  @override
  Future<ChallengeOutcome> requestPhoneSignInCode(
    String phoneNumber,
    CancelToken cancelToken, {
    PhoneSignInActor actor = PhoneSignInActor.client,
  }) => _challengeRequest(
    '/v1/auth/${actor == PhoneSignInActor.client ? 'client' : 'provider'}-code/request',
    {'phoneNumber': phoneNumber},
    cancelToken,
  );

  @override
  Future<AuthOutcome> verifyPhoneSignInCode(
    String challengeId,
    String code,
    CancelToken cancelToken, {
    PhoneSignInActor actor = PhoneSignInActor.client,
  }) => _verifyCode(
    '/v1/auth/${actor == PhoneSignInActor.client ? 'client' : 'provider'}-code/verify',
    challengeId,
    code,
    cancelToken,
  );

  @override
  Future<ChallengeOutcome> resendPhoneSignInCode(
    String challengeId,
    CancelToken cancelToken, {
    PhoneSignInActor actor = PhoneSignInActor.client,
  }) => _challengeRequest(
    '/v1/auth/${actor == PhoneSignInActor.client ? 'client' : 'provider'}-code/resend',
    {'challengeId': challengeId},
    cancelToken,
  );

  @override
  Future<ChallengeOutcome> registerClient(
    ClientRegistrationRequest request,
    CancelToken cancelToken,
  ) => _challengeRequest(
    '/v1/registrations/clients',
    request.toJson(),
    cancelToken,
  );

  @override
  Future<ChallengeOutcome> registerServiceProvider(
    ServiceProviderRegistrationRequest request,
    CancelToken cancelToken,
  ) => _challengeRequest(
    '/v1/registrations/service-providers',
    request.toJson(),
    cancelToken,
  );

  @override
  Future<AuthOutcome> verifyRegistration(
    String challengeId,
    String code,
    CancelToken cancelToken,
  ) => _verifyCode(
    '/v1/registrations/verify-phone',
    challengeId,
    code,
    cancelToken,
  );

  @override
  Future<ChallengeOutcome> resendRegistrationCode(
    String challengeId,
    CancelToken cancelToken,
  ) => _challengeRequest('/v1/registrations/resend-phone-code', {
    'challengeId': challengeId,
  }, cancelToken);

  Future<ChallengeOutcome> _challengeRequest(
    String path,
    Map<String, Object> data,
    CancelToken cancelToken,
  ) async {
    final configurationError = _config.validate();
    if (configurationError != null) {
      return ChallengeFailure(configurationError);
    }
    try {
      final response = await _dio.post<Object?>(
        path,
        data: data,
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (path == '/v1/auth/client-code/request' &&
          body is Map<String, dynamic> &&
          body['outcome'] == 'REGISTRATION_REQUIRED') {
        return const RegistrationRequired();
      }
      return ChallengeCreated(PhoneChallenge.fromJson(body));
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return const ChallengeFailure('The request was cancelled. Try again.');
      }
      final status = error.response?.statusCode;
      final body = error.response?.data;
      if (body is Map<String, dynamic> && (status == 400 || status == 429)) {
        final category = switch (body['limitCategory']) {
          'OTP_HOURLY' => RequestLimitCategory.hourly,
          'OTP_COOLDOWN' => RequestLimitCategory.cooldown,
          'CLIENT_REQUEST' => RequestLimitCategory.clientRequest,
          'PROVIDER_REQUEST' => RequestLimitCategory.providerRequest,
          _ => null,
        };
        final rawRetry = body['retryAt'];
        final retryAt = rawRetry is String
            ? DateTime.tryParse(rawRetry)?.toUtc()
            : null;
        if (category != null && retryAt != null) {
          final local = retryAt.toLocal();
          final time = [
            local.hour,
            local.minute,
            local.second,
          ].map((part) => part.toString().padLeft(2, '0')).join(':');
          final reason = switch (category) {
            RequestLimitCategory.hourly =>
              'The hourly verification-code limit has been reached.',
            RequestLimitCategory.cooldown =>
              'Please wait before requesting another code.',
            RequestLimitCategory.providerRequest =>
              'Too many Service Provider sign-in requests.',
            RequestLimitCategory.clientRequest =>
              'Too many Client sign-in requests.',
          };
          return ChallengeFailure(
            '$reason Try again at $time.',
            rateLimited: true,
            retryAt: retryAt,
            limitCategory: category,
          );
        }
      }
      if ((status == 401 || status == 403) &&
          path.contains('/provider-code/')) {
        return const ChallengeFailure(
          'Service Provider sign-in is unavailable. Check your registered phone or use Service Provider Registration to complete an unfinished registration.',
        );
      }
      if (status == 401 || status == 403) {
        return const ChallengeFailure(
          'Client sign-in is unavailable. If registration is unfinished, return to Client Registration to complete it.',
        );
      }
      if (status == 409) {
        return const ChallengeFailure(
          'These registration details are already in use. Sign in or correct the form.',
        );
      }
      if (status == 429) {
        return const ChallengeFailure(
          'Too many verification codes were requested. Try again later.',
          rateLimited: true,
        );
      }
      if (status == 400) {
        return const ChallengeFailure(
          'Check the information you entered and try again.',
        );
      }
      return const ChallengeFailure(
        'Weyonje could not send a verification code. Check your connection and try again.',
      );
    } on FormatException {
      return const ChallengeFailure(
        'Weyonje returned an invalid verification response. Try again.',
      );
    }
  }

  Future<AuthOutcome> _verifyCode(
    String path,
    String challengeId,
    String code,
    CancelToken cancelToken,
  ) async {
    _sessionGeneration++;
    _refreshInFlight = null;
    final configurationError = _config.validate();
    if (configurationError != null) {
      return TransientAuthFailure(configurationError);
    }
    try {
      final response = await _dio.post<Object?>(
        path,
        data: {'challengeId': challengeId, 'code': code},
        cancelToken: cancelToken,
      );
      final credentials = SessionCredentials.fromJson(response.data);
      if (cancelToken.isCancelled) return const CancelledSignIn();
      await _sessionStore.write(credentials);
      final resolved = await _resolve(
        credentials,
        cancelToken,
        allowRefresh: true,
      );
      return resolved is ResolvedSession || resolved is DeniedSession
          ? resolved
          : VerifiedSessionPending(resolved);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return const CancelledSignIn();
      if (error.response?.statusCode == 401) {
        final data = error.response?.data;
        if (data is Map && data['code'] == 'AUTH_VERIFICATION_EXPIRED') {
          return const CodeVerificationFailure(
            CodeFailureKind.expired,
            'This code has expired. Request another code.',
          );
        }
        return const CodeVerificationFailure(
          CodeFailureKind.invalid,
          'This code is incorrect or no longer usable. Check it or request another code.',
        );
      }
      if (error.response?.statusCode == 429) {
        return const CodeVerificationFailure(
          CodeFailureKind.exhausted,
          'No verification attempts remain. Request another code when available.',
        );
      }
      return const TransientAuthFailure(
        'The verification response was interrupted. Check your connection and retry. If the code is no longer usable, return to sign in for a new code.',
      );
    } on FormatException {
      await _sessionStore.clear();
      return const TransientAuthFailure(
        'The verification response was interrupted. Request a new sign-in code if retry fails.',
      );
    } catch (_) {
      return const TransientAuthFailure(
        'Your session could not be saved. Retry or request a new sign-in code.',
      );
    }
  }

  Future<AuthOutcome> _resolve(
    SessionCredentials credentials,
    CancelToken cancelToken, {
    required bool allowRefresh,
  }) async {
    final generation = _sessionGeneration;
    if (allowRefresh &&
        credentials.accessTokenExpiresAt.isBefore(
          DateTime.now().toUtc().add(const Duration(seconds: 10)),
        )) {
      final refreshed = await _refreshOnce(credentials, cancelToken);
      if (refreshed is SessionCredentials) {
        return _resolve(refreshed, cancelToken, allowRefresh: false);
      }
      return refreshed as AuthOutcome;
    }
    try {
      final response = await _dio.get<Object?>(
        '/v1/actors/me',
        cancelToken: cancelToken,
        options: _bearer(credentials.accessToken),
      );
      if (cancelToken.isCancelled || generation != _sessionGeneration) {
        return const CancelledSignIn();
      }
      return ResolvedSession(CurrentActor.fromJson(response.data));
    } on DioException catch (error) {
      if (generation != _sessionGeneration) return const CancelledSignIn();
      if (CancelToken.isCancel(error)) {
        return const TransientAuthFailure(
          'The session check was cancelled. Retry to continue.',
        );
      }
      final status = error.response?.statusCode;
      if (status == 401 && allowRefresh) {
        final refreshed = await _refreshOnce(credentials, cancelToken);
        if (refreshed is SessionCredentials) {
          return _resolve(refreshed, cancelToken, allowRefresh: false);
        }
        return refreshed as AuthOutcome;
      }
      if (status == 401) {
        await _sessionStore.clear();
        return const InvalidSession('Your session has expired. Sign in again.');
      }
      if (status == 403) {
        return const DeniedSession(
          'This account is not permitted to use Weyonje mobile services.',
        );
      }
      return const TransientAuthFailure(
        'Weyonje could not verify your session. Check your connection and retry.',
      );
    } on FormatException {
      return const DeniedSession(
        'Weyonje could not confirm a recognized account profile.',
      );
    } catch (_) {
      return const TransientAuthFailure(
        'Weyonje could not verify your session. Retry in a moment.',
      );
    }
  }

  Future<Object> _refreshOnce(
    SessionCredentials credentials,
    CancelToken cancelToken,
  ) {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final refresh = _refresh(credentials, cancelToken);
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  Future<Object> _refresh(
    SessionCredentials credentials,
    CancelToken cancelToken,
  ) async {
    final generation = _sessionGeneration;
    try {
      final response = await _dio.post<Object?>(
        '/v1/auth/refresh',
        data: {'refreshToken': credentials.refreshToken},
        cancelToken: cancelToken,
      );
      final refreshed = SessionCredentials.fromJson(response.data);
      if (cancelToken.isCancelled || generation != _sessionGeneration) {
        return const TransientAuthFailure('Session renewal was cancelled.');
      }
      await _sessionStore.write(refreshed);
      return refreshed;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return const TransientAuthFailure(
          'Session renewal was cancelled. Retry to continue.',
        );
      }
      if (error.response?.statusCode == 401) {
        if (generation != _sessionGeneration) {
          return const CancelledSignIn();
        }
        await _sessionStore.clear();
        return const InvalidSession(
          'Your session can no longer be renewed. Sign in again.',
        );
      }
      return const TransientAuthFailure(
        'Weyonje could not renew your session. Check your connection and retry.',
      );
    } on FormatException {
      if (!cancelToken.isCancelled && generation == _sessionGeneration) {
        await _sessionStore.clear();
      }
      return const InvalidSession(
        'Your session can no longer be renewed. Sign in again.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    final generation = ++_sessionGeneration;
    _refreshInFlight = null;
    final stored = await _sessionStore.read();
    try {
      if (stored != null && _config.validate() == null) {
        await _dio.post<Object?>(
          '/v1/auth/sign-out',
          options: _bearer(stored.accessToken),
        );
      }
    } catch (_) {
      // Local credentials must be cleared even when server revocation is offline.
    } finally {
      if (generation == _sessionGeneration) await _sessionStore.clear();
    }
  }

  Options _bearer(String accessToken) =>
      Options(headers: {'Authorization': 'Bearer $accessToken'});
}
