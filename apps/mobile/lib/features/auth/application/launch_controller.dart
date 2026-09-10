import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/current_actor.dart';
import '../../../core/notifications/push_notification_coordinator.dart';
import '../../workflows/application/journey_tracking_coordinator.dart';

sealed class LaunchState {
  const LaunchState();
}

class LaunchChecking extends LaunchState {
  const LaunchChecking({this.isRetry = false});
  final bool isRetry;
}

class LaunchUnauthenticated extends LaunchState {
  const LaunchUnauthenticated({this.message});
  final String? message;
}

class LaunchTransientError extends LaunchState {
  const LaunchTransientError(this.message, {this.retryInProgress = false});
  final String message;
  final bool retryInProgress;
}

class LaunchAuthenticated extends LaunchState {
  const LaunchAuthenticated(this.actor);
  final CurrentActor actor;
}

class LaunchAccessDenied extends LaunchState {
  const LaunchAccessDenied(this.message);
  final String message;
}

final launchControllerProvider =
    NotifierProvider<LaunchController, LaunchState>(LaunchController.new);

class LaunchController extends Notifier<LaunchState> {
  bool _inProgress = false;
  bool _started = false;
  int _generation = 0;
  CancelToken? _cancelToken;

  @override
  LaunchState build() {
    ref.onDispose(cancelActiveCheck);
    return const LaunchChecking();
  }

  Future<void> initialize() async {
    if (_started) return;
    _started = true;
    await _check(isRetry: false);
  }

  Future<void> retry() => _check(isRetry: true);

  Future<void> revalidateOnResume() async {
    final shouldRevalidate =
        state is LaunchAuthenticated ||
        state is LaunchAccessDenied ||
        (_started && state is LaunchChecking);
    if (!shouldRevalidate) return;
    await _check(isRetry: false);
  }

  Future<void> _check({required bool isRetry}) async {
    if (_inProgress) return;
    _inProgress = true;
    final generation = ++_generation;
    _cancelToken?.cancel('A newer session check replaced this request.');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    if (isRetry && state is LaunchTransientError) {
      state = LaunchTransientError(
        (state as LaunchTransientError).message,
        retryInProgress: true,
      );
    } else {
      state = LaunchChecking(isRetry: isRetry);
    }
    try {
      final outcome = await ref
          .read(authRepositoryProvider)
          .resolveStoredSession(cancelToken);
      if (generation == _generation && !cancelToken.isCancelled) {
        _apply(outcome);
      }
    } finally {
      if (generation == _generation) {
        _inProgress = false;
        _cancelToken = null;
      }
    }
  }

  void acceptSignInOutcome(AuthOutcome outcome) => _apply(outcome);

  void _apply(AuthOutcome outcome) {
    state = switch (outcome) {
      NoStoredSession() => const LaunchUnauthenticated(),
      ResolvedSession(:final actor) =>
        actor.access == ActorAccess.denied
            ? const LaunchAccessDenied(
                'This account is not permitted to use Weyonje mobile services.',
              )
            : LaunchAuthenticated(actor),
      InvalidSession(:final message) => LaunchUnauthenticated(message: message),
      TransientAuthFailure(:final message) => LaunchTransientError(message),
      RateLimitedAuthFailure(:final message) => LaunchTransientError(message),
      DeniedSession(:final message) => LaunchAccessDenied(message),
      CancelledSignIn() => const LaunchUnauthenticated(),
      CodeVerificationFailure(:final message) => LaunchUnauthenticated(
        message: message,
      ),
      VerifiedSessionPending() => const LaunchTransientError(
        'Phone verified. Retry the session check to continue.',
      ),
    };
  }

  Future<void> signOut() async {
    cancelActiveCheck();
    await ref.read(pushNotificationCoordinatorProvider).disable();
    await ref.read(journeyTrackingCoordinatorProvider).clear();
    await ref.read(authRepositoryProvider).signOut();
    state = const LaunchUnauthenticated(message: 'You have signed out.');
  }

  void cancelActiveCheck() {
    _generation++;
    _inProgress = false;
    _cancelToken?.cancel('Application lifecycle changed.');
    _cancelToken = null;
  }
}
