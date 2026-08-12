import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/registration_models.dart';
import 'launch_controller.dart';

class RegistrationState {
  const RegistrationState({
    this.inProgress = false,
    this.message,
    this.rateLimited = false,
  });

  final bool inProgress;
  final String? message;
  final bool rateLimited;
}

final registrationControllerProvider =
    NotifierProvider.autoDispose<RegistrationController, RegistrationState>(
      RegistrationController.new,
    );

class RegistrationController extends Notifier<RegistrationState> {
  bool _inProgress = false;
  CancelToken? _cancelToken;

  @override
  RegistrationState build() {
    ref.onDispose(() => _cancelToken?.cancel('Registration screen closed.'));
    return const RegistrationState();
  }

  Future<PhoneChallenge?> submitClient(ClientRegistrationRequest request) =>
      _submit(
        (token) =>
            ref.read(authRepositoryProvider).registerClient(request, token),
      );

  Future<PhoneChallenge?> submitServiceProvider(
    ServiceProviderRegistrationRequest request,
  ) => _submit(
    (token) => ref
        .read(authRepositoryProvider)
        .registerServiceProvider(request, token),
  );

  Future<PhoneChallenge?> _submit(
    Future<ChallengeOutcome> Function(CancelToken token) operation,
  ) async {
    if (_inProgress) return null;
    _inProgress = true;
    final token = CancelToken();
    _cancelToken = token;
    state = const RegistrationState(inProgress: true);
    final outcome = await operation(token);
    if (token.isCancelled) return null;
    _inProgress = false;
    _cancelToken = null;
    return switch (outcome) {
      ChallengeCreated(:final challenge) => () {
        state = const RegistrationState();
        return challenge;
      }(),
      ChallengeFailure(:final message, :final rateLimited) => () {
        state = RegistrationState(message: message, rateLimited: rateLimited);
        return null;
      }(),
    };
  }
}

final clientCodeControllerProvider =
    NotifierProvider.autoDispose<ClientCodeController, RegistrationState>(
      ClientCodeController.new,
    );

class ClientCodeController extends Notifier<RegistrationState> {
  bool _inProgress = false;
  CancelToken? _cancelToken;

  @override
  RegistrationState build() {
    ref.onDispose(() => _cancelToken?.cancel('Client sign-in closed.'));
    return const RegistrationState();
  }

  Future<PhoneChallenge?> requestCode(String phoneNumber) async {
    if (_inProgress) return null;
    _inProgress = true;
    final token = CancelToken();
    _cancelToken = token;
    state = const RegistrationState(inProgress: true);
    final outcome = await ref
        .read(authRepositoryProvider)
        .requestClientCode(phoneNumber, token);
    if (token.isCancelled) return null;
    _inProgress = false;
    _cancelToken = null;
    return switch (outcome) {
      ChallengeCreated(:final challenge) => () {
        state = const RegistrationState();
        return challenge;
      }(),
      ChallengeFailure(:final message, :final rateLimited) => () {
        state = RegistrationState(message: message, rateLimited: rateLimited);
        return null;
      }(),
    };
  }
}

class PhoneVerificationState {
  const PhoneVerificationState({
    this.inProgress = false,
    this.resending = false,
    this.message,
    this.rateLimited = false,
  });

  final bool inProgress;
  final bool resending;
  final String? message;
  final bool rateLimited;
}

final phoneVerificationControllerProvider =
    NotifierProvider.autoDispose<
      PhoneVerificationController,
      PhoneVerificationState
    >(PhoneVerificationController.new);

class PhoneVerificationController extends Notifier<PhoneVerificationState> {
  bool _inProgress = false;
  CancelToken? _cancelToken;

  @override
  PhoneVerificationState build() {
    ref.onDispose(() => _cancelToken?.cancel('Verification screen closed.'));
    return const PhoneVerificationState();
  }

  Future<void> verify(PhoneVerificationArguments arguments, String code) async {
    if (_inProgress) return;
    _inProgress = true;
    final token = CancelToken();
    _cancelToken = token;
    state = const PhoneVerificationState(inProgress: true);
    final repository = ref.read(authRepositoryProvider);
    final outcome = arguments.purpose == PhoneVerificationPurpose.registration
        ? await repository.verifyRegistration(
            arguments.challenge.id,
            code,
            token,
          )
        : await repository.verifyClientCode(
            arguments.challenge.id,
            code,
            token,
          );
    if (token.isCancelled) return;
    _inProgress = false;
    _cancelToken = null;
    switch (outcome) {
      case ResolvedSession() || DeniedSession():
        state = const PhoneVerificationState();
        ref
            .read(launchControllerProvider.notifier)
            .acceptSignInOutcome(outcome);
      case RateLimitedAuthFailure(:final message):
        state = PhoneVerificationState(message: message, rateLimited: true);
      case InvalidSession(:final message) ||
          TransientAuthFailure(:final message):
        state = PhoneVerificationState(message: message);
      case CancelledSignIn():
        state = const PhoneVerificationState();
      default:
        state = const PhoneVerificationState(
          message: 'Verification could not be completed. Try again.',
        );
    }
  }

  Future<PhoneChallenge?> resend(PhoneVerificationArguments arguments) async {
    if (_inProgress) return null;
    _inProgress = true;
    final token = CancelToken();
    _cancelToken = token;
    state = const PhoneVerificationState(resending: true);
    final repository = ref.read(authRepositoryProvider);
    final outcome = arguments.purpose == PhoneVerificationPurpose.registration
        ? await repository.resendRegistrationCode(arguments.challenge.id, token)
        : await repository.resendClientCode(arguments.challenge.id, token);
    if (token.isCancelled) return null;
    _inProgress = false;
    _cancelToken = null;
    return switch (outcome) {
      ChallengeCreated(:final challenge) => () {
        state = const PhoneVerificationState();
        return challenge;
      }(),
      ChallengeFailure(:final message, :final rateLimited) => () {
        state = PhoneVerificationState(
          message: message,
          rateLimited: rateLimited,
        );
        return null;
      }(),
    };
  }
}
