import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/sms_retriever.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/registration_models.dart';
import 'launch_controller.dart';

class RegistrationState {
  const RegistrationState({
    this.inProgress = false,
    this.message,
    this.rateLimited = false,
    this.retryAt,
    this.registrationRequired = false,
  });

  final bool inProgress;
  final String? message;
  final bool rateLimited;
  final DateTime? retryAt;
  final bool registrationRequired;
  bool get waiting => retryAt != null && DateTime.now().isBefore(retryAt!);
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
    final retrieval = ref.read(smsRetrievalProvider);
    ref.onDispose(() {
      if (_cancelToken != null) unawaited(retrieval.stop());
      _cancelToken?.cancel('Registration screen closed.');
    });
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
    if (_inProgress || state.waiting) return null;
    _inProgress = true;
    final token = CancelToken();
    _cancelToken = token;
    state = const RegistrationState(inProgress: true);
    await ref.read(smsRetrievalProvider).start();
    if (token.isCancelled) return null;
    final outcome = await operation(token);
    if (token.isCancelled) return null;
    _inProgress = false;
    _cancelToken = null;
    return switch (outcome) {
      RegistrationRequired() => () {
        unawaited(ref.read(smsRetrievalProvider).stop());
        state = const RegistrationState(registrationRequired: true);
        return null;
      }(),
      ChallengeCreated(:final challenge) => () {
        state = const RegistrationState();
        return challenge;
      }(),
      ChallengeFailure(:final message, :final rateLimited, :final retryAt) =>
        () {
          unawaited(ref.read(smsRetrievalProvider).stop());
          state = RegistrationState(
            message: message,
            rateLimited: rateLimited,
            retryAt: retryAt,
          );
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
    final retrieval = ref.read(smsRetrievalProvider);
    ref.onDispose(() {
      if (_cancelToken != null) unawaited(retrieval.stop());
      _cancelToken?.cancel('Client sign-in closed.');
    });
    return const RegistrationState();
  }

  Future<PhoneChallenge?> requestCode(String phoneNumber) async {
    if (_inProgress || state.waiting) return null;
    _inProgress = true;
    final token = CancelToken();
    _cancelToken = token;
    state = const RegistrationState(inProgress: true);
    await ref.read(smsRetrievalProvider).start();
    if (token.isCancelled) return null;
    final outcome = await ref
        .read(authRepositoryProvider)
        .requestClientCode(phoneNumber, token);
    if (token.isCancelled) return null;
    _inProgress = false;
    _cancelToken = null;
    return switch (outcome) {
      RegistrationRequired() => () {
        unawaited(ref.read(smsRetrievalProvider).stop());
        state = const RegistrationState(registrationRequired: true);
        return null;
      }(),
      ChallengeCreated(:final challenge) => () {
        state = const RegistrationState();
        return challenge;
      }(),
      ChallengeFailure(:final message, :final rateLimited, :final retryAt) =>
        () {
          unawaited(ref.read(smsRetrievalProvider).stop());
          state = RegistrationState(
            message: message,
            rateLimited: rateLimited,
            retryAt: retryAt,
          );
          return null;
        }(),
    };
  }
}

enum VerificationPhase {
  entry,
  checking,
  invalid,
  expired,
  exhausted,
  network,
  success,
}

class PhoneVerificationState {
  const PhoneVerificationState({
    this.phase = VerificationPhase.entry,
    this.resending = false,
    this.retryAt,
    this.message,
  });
  final VerificationPhase phase;
  final bool resending;
  final DateTime? retryAt;
  bool get waiting => retryAt != null && DateTime.now().isBefore(retryAt!);
  final String? message;
  bool get inProgress =>
      phase == VerificationPhase.checking || phase == VerificationPhase.success;
  bool get rateLimited => phase == VerificationPhase.exhausted;
}

final phoneVerificationControllerProvider = NotifierProvider.autoDispose
    .family<PhoneVerificationController, PhoneVerificationState, String>(
      PhoneVerificationController.new,
    );

class PhoneVerificationController extends Notifier<PhoneVerificationState> {
  PhoneVerificationController(this.flowId);
  final String flowId;
  CancelToken? _cancelToken;
  Timer? _successTimer;
  String? _attempt;
  bool _closed = false;
  DateTime? _resendRetryAt;
  bool get waitingToResend =>
      _resendRetryAt != null && DateTime.now().isBefore(_resendRetryAt!);

  @override
  PhoneVerificationState build() {
    ref.onDispose(abandon);
    return const PhoneVerificationState();
  }

  void abandon() {
    _closed = true;
    _cancelToken?.cancel('Verification screen closed.');
    _successTimer?.cancel();
  }

  void edited() {
    if (state.inProgress || state.resending) return;
    if (state.phase == VerificationPhase.invalid ||
        state.phase == VerificationPhase.network) {
      state = const PhoneVerificationState();
    }
  }

  Future<void> verify(
    PhoneVerificationArguments arguments,
    String code, {
    bool retry = false,
  }) async {
    final attempt = '${arguments.challenge.id}:$code';
    if (_closed ||
        state.inProgress ||
        state.resending ||
        !RegExp(r'^\d{6}$').hasMatch(code) ||
        (!retry && _attempt == attempt) ||
        state.phase == VerificationPhase.expired ||
        state.phase == VerificationPhase.exhausted) {
      return;
    }
    _attempt = attempt;
    final token = CancelToken();
    _cancelToken = token;
    state = const PhoneVerificationState(
      phase: VerificationPhase.checking,
      message: 'Checking your code…',
    );
    final repository = ref.read(authRepositoryProvider);
    AuthOutcome outcome;
    try {
      outcome = arguments.purpose == PhoneVerificationPurpose.registration
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
    } catch (_) {
      outcome = const TransientAuthFailure(
        'Verification was interrupted. Check your connection, then retry or request a new sign-in code.',
      );
    }
    if (_closed || token.isCancelled) return;
    _cancelToken = null;
    switch (outcome) {
      case ResolvedSession() || DeniedSession() || VerifiedSessionPending():
        state = const PhoneVerificationState(
          phase: VerificationPhase.success,
          message: 'Phone verified. Continuing…',
        );
        _successTimer = Timer(const Duration(milliseconds: 650), () {
          if (_closed) return;
          ref
              .read(launchControllerProvider.notifier)
              .acceptSignInOutcome(
                outcome is VerifiedSessionPending ? outcome.outcome : outcome,
              );
        });
      case CodeVerificationFailure(:final kind, :final message):
        state = PhoneVerificationState(
          phase: switch (kind) {
            CodeFailureKind.invalid => VerificationPhase.invalid,
            CodeFailureKind.expired => VerificationPhase.expired,
            CodeFailureKind.exhausted => VerificationPhase.exhausted,
          },
          message: message,
        );
      case InvalidSession(:final message):
        state = PhoneVerificationState(
          phase: VerificationPhase.invalid,
          message: message,
        );
      case RateLimitedAuthFailure(:final message):
        state = PhoneVerificationState(
          phase: VerificationPhase.exhausted,
          message: message,
        );
      case TransientAuthFailure(:final message):
        state = PhoneVerificationState(
          phase: VerificationPhase.network,
          message: message,
        );
      default:
        state = const PhoneVerificationState();
    }
  }

  Future<PhoneChallenge?> resend(PhoneVerificationArguments arguments) async {
    if (_closed || state.inProgress || state.resending || waitingToResend) {
      return null;
    }
    final token = CancelToken();
    _cancelToken = token;
    state = const PhoneVerificationState(resending: true);
    final retrieval = ref.read(smsRetrievalProvider);
    await retrieval.start();
    if (_closed || token.isCancelled) return null;
    final repository = ref.read(authRepositoryProvider);
    ChallengeOutcome outcome;
    try {
      outcome = arguments.purpose == PhoneVerificationPurpose.registration
          ? await repository.resendRegistrationCode(
              arguments.challenge.id,
              token,
            )
          : await repository.resendClientCode(arguments.challenge.id, token);
    } catch (_) {
      outcome = const ChallengeFailure(
        'The resend response was interrupted. Wait before requesting another code.',
      );
    }
    if (_closed || token.isCancelled) return null;
    _cancelToken = null;
    switch (outcome) {
      case ChallengeCreated(:final challenge):
        _attempt = null;
        state = const PhoneVerificationState();
        return challenge;
      case RegistrationRequired():
        state = const PhoneVerificationState(
          message: 'The resend response was invalid.',
        );
        return null;
      case ChallengeFailure(:final message, :final retryAt):
        _resendRetryAt = retryAt;
        state = PhoneVerificationState(
          phase: VerificationPhase.network,
          message: message,
          retryAt: retryAt,
        );
        return null;
    }
  }
}
