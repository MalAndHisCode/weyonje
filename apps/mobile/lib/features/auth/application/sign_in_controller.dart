import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_repository.dart';
import 'launch_controller.dart';

class SignInState {
  const SignInState({
    this.inProgress = false,
    this.message,
    this.rateLimited = false,
  });
  final bool inProgress;
  final String? message;
  final bool rateLimited;
}

final signInControllerProvider =
    NotifierProvider.autoDispose<SignInController, SignInState>(
      SignInController.new,
    );

class SignInController extends Notifier<SignInState> {
  bool _inProgress = false;
  CancelToken? _cancelToken;

  @override
  SignInState build() {
    ref.onDispose(() => _cancelToken?.cancel('Sign-in screen closed.'));
    return const SignInState();
  }

  Future<void> signIn(String email, String password) async {
    if (_inProgress) return;
    _inProgress = true;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = const SignInState(inProgress: true);
    final outcome = await ref
        .read(authRepositoryProvider)
        .signIn(email, password, cancelToken);
    if (cancelToken.isCancelled) return;
    _inProgress = false;
    _cancelToken = null;
    switch (outcome) {
      case CancelledSignIn():
        state = const SignInState();
      case RateLimitedAuthFailure(:final message):
        state = SignInState(message: message, rateLimited: true);
      case TransientAuthFailure(:final message):
        state = SignInState(message: message);
      case InvalidSession(:final message):
        state = SignInState(message: message);
      default:
        state = const SignInState();
        ref
            .read(launchControllerProvider.notifier)
            .acceptSignInOutcome(outcome);
    }
  }
}
