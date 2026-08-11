import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

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

class DeniedSession extends AuthOutcome {
  const DeniedSession(this.message);
  final String message;
}

class CancelledSignIn extends AuthOutcome {
  const CancelledSignIn();
}

abstract interface class AuthRepository {
  Future<AuthOutcome> resolveStoredSession(CancelToken cancelToken);
  Future<AuthOutcome> signIn();
  Future<void> signOut();
}

class OidcAuthRepository implements AuthRepository {
  OidcAuthRepository(
    this._config,
    this._sessionStore,
    this._dio,
    this._appAuth,
  );

  final AppConfig _config;
  final SessionStore _sessionStore;
  final Dio _dio;
  final FlutterAppAuth _appAuth;

  @override
  Future<AuthOutcome> resolveStoredSession(CancelToken cancelToken) async {
    final stored = await _sessionStore.read();
    if (stored == null) {
      return const NoStoredSession();
    }
    final configurationError = _config.validate();
    if (configurationError != null) {
      return TransientAuthFailure(configurationError);
    }
    return _resolve(stored, cancelToken, allowRefresh: true);
  }

  @override
  Future<AuthOutcome> signIn() async {
    final configurationError = _config.validate();
    if (configurationError != null) {
      return TransientAuthFailure(configurationError);
    }
    try {
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _config.keycloakClientId,
          _config.redirectUri,
          discoveryUrl: _config.discoveryUrl,
          scopes: const ['openid'],
        ),
      );
      final credentials = _credentialsFromResponse(response);
      if (credentials == null) {
        await _sessionStore.clear();
        return const InvalidSession(
          'Sign-in did not return a usable session. Try again.',
        );
      }
      await _sessionStore.write(credentials);
      return _resolve(credentials, CancelToken(), allowRefresh: true);
    } on PlatformException catch (error) {
      if (_isCancellation(error)) return const CancelledSignIn();
      if (_isUnrecoverableOidcError(error)) {
        await _sessionStore.clear();
        return const InvalidSession(
          'Sign-in could not be completed. Start again.',
        );
      }
      return const TransientAuthFailure(
        'The identity service could not be reached. Check your connection and try again.',
      );
    } catch (_) {
      return const TransientAuthFailure(
        'Sign-in could not be completed. Check your connection and try again.',
      );
    }
  }

  Future<AuthOutcome> _resolve(
    SessionCredentials credentials,
    CancelToken cancelToken, {
    required bool allowRefresh,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '/v1/actors/me',
        cancelToken: cancelToken,
        options: Options(
          headers: {'Authorization': 'Bearer ${credentials.accessToken}'},
        ),
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
        final refreshed = await _refresh(credentials);
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

  Future<Object> _refresh(SessionCredentials credentials) async {
    final refreshToken = credentials.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _sessionStore.clear();
      return const InvalidSession('Your session has expired. Sign in again.');
    }
    try {
      final response = await _appAuth.token(
        TokenRequest(
          _config.keycloakClientId,
          _config.redirectUri,
          discoveryUrl: _config.discoveryUrl,
          refreshToken: refreshToken,
          scopes: const ['openid'],
        ),
      );
      final refreshed = _credentialsFromResponse(
        response,
        previousRefreshToken: refreshToken,
      );
      if (refreshed == null) {
        await _sessionStore.clear();
        return const InvalidSession(
          'Your session can no longer be renewed. Sign in again.',
        );
      }
      await _sessionStore.write(refreshed);
      return refreshed;
    } on PlatformException catch (error) {
      if (_isUnrecoverableOidcError(error)) {
        await _sessionStore.clear();
        return const InvalidSession(
          'Your session can no longer be renewed. Sign in again.',
        );
      }
      return const TransientAuthFailure(
        'The identity service could not renew your session. Check your connection and retry.',
      );
    } catch (_) {
      return const TransientAuthFailure(
        'The identity service could not renew your session. Check your connection and retry.',
      );
    }
  }

  SessionCredentials? _credentialsFromResponse(
    TokenResponse? response, {
    String? previousRefreshToken,
  }) {
    final accessToken = response?.accessToken;
    if (accessToken == null || accessToken.isEmpty) return null;
    return SessionCredentials(
      accessToken: accessToken,
      refreshToken: response?.refreshToken ?? previousRefreshToken,
      idToken: response?.idToken,
      accessTokenExpiration: response?.accessTokenExpirationDateTime,
    );
  }

  bool _isCancellation(PlatformException error) =>
      error.code.toLowerCase().contains('cancel') ||
      '${error.details}'.toLowerCase().contains('cancel');

  bool _isUnrecoverableOidcError(PlatformException error) {
    final detail = '${error.code} ${error.message} ${error.details}'
        .toLowerCase();
    return detail.contains('invalid_grant') ||
        detail.contains('invalid_client') ||
        detail.contains('unauthorized_client') ||
        detail.contains('access_denied');
  }

  @override
  Future<void> signOut() => _sessionStore.clear();
}
