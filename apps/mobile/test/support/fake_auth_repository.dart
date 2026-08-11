import 'package:dio/dio.dart';
import 'package:weyonje/core/auth/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({required this.onResolve, this.onSignIn});

  Future<AuthOutcome> Function(CancelToken cancelToken) onResolve;
  Future<AuthOutcome> Function(
    String email,
    String password,
    CancelToken cancelToken,
  )?
  onSignIn;
  int resolveCalls = 0;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AuthOutcome> resolveStoredSession(CancelToken cancelToken) {
    resolveCalls++;
    return onResolve(cancelToken);
  }

  @override
  Future<AuthOutcome> signIn(
    String email,
    String password,
    CancelToken cancelToken,
  ) {
    signInCalls++;
    return onSignIn?.call(email, password, cancelToken) ??
        Future.value(const CancelledSignIn());
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
