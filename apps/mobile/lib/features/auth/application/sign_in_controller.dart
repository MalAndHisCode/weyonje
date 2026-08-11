import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_repository.dart';
import 'launch_controller.dart';

class SignInState {
  const SignInState({this.inProgress = false, this.message});
  final bool inProgress;
  final String? message;
}

final signInControllerProvider =
    NotifierProvider.autoDispose<SignInController, SignInState>(
      SignInController.new,
    );

class SignInController extends Notifier<SignInState> {
  bool _inProgress = false;

  @override
  SignInState build() => const SignInState();

  Future<void> signIn() async {
    if (_inProgress) return;
    _inProgress = true;
    state = const SignInState(inProgress: true);
    final outcome = await ref.read(authRepositoryProvider).signIn();
    _inProgress = false;
    switch (outcome) {
      case CancelledSignIn():
        state = const SignInState(
          message: 'Sign-in was cancelled. You can try again when ready.',
        );
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
