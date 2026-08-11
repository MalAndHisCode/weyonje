import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'current_actor.dart';
import 'session_credentials.dart';
import 'session_store.dart';

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

abstract interface class AuthRepository {
  Future<AuthOutcome> resolveStoredSession(CancelToken cancelToken);
  Future<AuthOutcome> signIn(
    String email,
    String password,
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
  Future<AuthOutcome> signIn(
    String email,
    String password,
    CancelToken cancelToken,
  ) async {
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

  Future<AuthOutcome> _resolve(
    SessionCredentials credentials,
    CancelToken cancelToken, {
    required bool allowRefresh,
  }) async {
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
      return ResolvedSession(CurrentActor.fromJson(response.data));
    } on DioException catch (error) {
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
    try {
      final response = await _dio.post<Object?>(
        '/v1/auth/refresh',
        data: {'refreshToken': credentials.refreshToken},
        cancelToken: cancelToken,
      );
      final refreshed = SessionCredentials.fromJson(response.data);
      await _sessionStore.write(refreshed);
      return refreshed;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return const TransientAuthFailure(
          'Session renewal was cancelled. Retry to continue.',
        );
      }
      if (error.response?.statusCode == 401) {
        await _sessionStore.clear();
        return const InvalidSession(
          'Your session can no longer be renewed. Sign in again.',
        );
      }
      return const TransientAuthFailure(
        'Weyonje could not renew your session. Check your connection and retry.',
      );
    } on FormatException {
      await _sessionStore.clear();
      return const InvalidSession(
        'Your session can no longer be renewed. Sign in again.',
      );
    }
  }

  @override
  Future<void> signOut() async {
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
      await _sessionStore.clear();
    }
  }

  Options _bearer(String accessToken) =>
      Options(headers: {'Authorization': 'Bearer $accessToken'});
}
