import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_store.dart';

class AccountChallenge {
  const AccountChallenge({
    required this.id,
    required this.expiresAt,
    required this.resendAvailableAt,
    this.developmentCode,
  });

  factory AccountChallenge.fromJson(Object? value) {
    final map = (value as Map).cast<String, dynamic>();
    return AccountChallenge(
      id: map['challengeId'] as String,
      expiresAt: DateTime.parse(map['expiresAt'] as String).toLocal(),
      resendAvailableAt: DateTime.parse(
        map['resendAvailableAt'] as String,
      ).toLocal(),
      developmentCode: map['developmentVerificationCode'] as String?,
    );
  }

  final String id;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
  final String? developmentCode;
}

class AccountSecurityFailure implements Exception {
  const AccountSecurityFailure(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class AccountSecurityRepository {
  AccountSecurityRepository(this._dio, this._sessions);
  final Dio _dio;
  final SessionStore _sessions;

  Future<AccountChallenge> requestRecovery(String email, String method) =>
      _challenge('/v1/account-security/password-recovery/request', {
        'email': email.trim(),
        'method': method,
      });

  Future<AccountChallenge> resendRecovery(String challengeId) => _challenge(
    '/v1/account-security/password-recovery/resend',
    {'challengeId': challengeId},
  );

  Future<void> completeRecovery(
    String challengeId,
    String code,
    String password,
  ) => _complete('/v1/account-security/password-recovery/complete', {
    'challengeId': challengeId,
    'code': code,
    'newPassword': password,
  });

  Future<AccountChallenge> requestEmailVerification(String method) async {
    final session = await _sessions.read();
    if (session == null) {
      throw const AccountSecurityFailure(
        'Your session expired. Sign in again.',
        code: 'AUTHENTICATION_REQUIRED',
      );
    }
    return _challenge(
      '/v1/account-security/email-verification/request',
      {'method': method},
      options: Options(
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      ),
    );
  }

  Future<AccountChallenge> resendEmailVerification(String challengeId) =>
      _challenge('/v1/account-security/email-verification/resend', {
        'challengeId': challengeId,
      });

  Future<void> verifyEmail(String challengeId, String code) => _complete(
    '/v1/account-security/email-verification/verify',
    {'challengeId': challengeId, 'code': code},
  );

  Future<AccountChallenge> _challenge(
    String path,
    Map<String, Object> data, {
    Options? options,
  }) async {
    try {
      return AccountChallenge.fromJson(
        (await _dio.post<Object?>(path, data: data, options: options)).data,
      );
    } on DioException catch (error) {
      throw _failure(error);
    } on FormatException {
      throw const AccountSecurityFailure(
        'Weyonje returned an invalid verification response.',
      );
    }
  }

  Future<void> _complete(String path, Map<String, Object> data) async {
    try {
      await _dio.post<Object?>(path, data: data);
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  AccountSecurityFailure _failure(DioException error) {
    final body = error.response?.data;
    final code = body is Map ? body['code'] as String? : null;
    final message = switch (code) {
      'ACCOUNT_CHALLENGE_EXPIRED' => 'This code expired. Request a new code.',
      'ACCOUNT_CHALLENGE_USED' => 'This code was already used.',
      'ACCOUNT_CHALLENGE_SUPERSEDED' =>
        'A newer code was requested. Use the most recent code.',
      'ACCOUNT_CHALLENGE_INVALID' =>
        'The code is incorrect or no longer usable.',
      'AUTH_RATE_LIMITED' => 'Too many attempts. Wait before trying again.',
      _ => 'Weyonje could not complete verification. Check your connection.',
    };
    return AccountSecurityFailure(message, code: code);
  }
}

final accountSecurityRepositoryProvider = Provider<AccountSecurityRepository>(
  (ref) => AccountSecurityRepository(
    ref.watch(dioProvider),
    ref.watch(sessionStoreProvider),
  ),
);
