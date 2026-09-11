import 'package:dio/dio.dart';
import 'package:weyonje/core/auth/auth_repository.dart';
import 'package:weyonje/core/auth/registration_models.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    required this.onResolve,
    this.onSignIn,
    this.onRequestClientCode,
    this.onVerifyClientCode,
    this.onRegisterClient,
    this.onRegisterServiceProvider,
    this.onVerifyRegistration,
    this.onResendClientCode,
    this.onResendRegistrationCode,
  });

  Future<AuthOutcome> Function(CancelToken) onResolve;
  Future<AuthOutcome> Function(String, String, CancelToken)? onSignIn;
  Future<ChallengeOutcome> Function(String, CancelToken)? onRequestClientCode;
  Future<AuthOutcome> Function(String, String, CancelToken)? onVerifyClientCode;
  Future<ChallengeOutcome> Function(ClientRegistrationRequest, CancelToken)?
  onRegisterClient;
  Future<ChallengeOutcome> Function(
    ServiceProviderRegistrationRequest,
    CancelToken,
  )?
  onRegisterServiceProvider;
  Future<AuthOutcome> Function(String, String, CancelToken)?
  onVerifyRegistration;
  Future<ChallengeOutcome> Function(String, CancelToken)? onResendClientCode;
  Future<ChallengeOutcome> Function(String, CancelToken)?
  onResendRegistrationCode;

  PhoneSignInActor? lastPhoneActor;
  int resolveCalls = 0;
  int signInCalls = 0;
  int requestClientCodeCalls = 0;
  int verifyClientCodeCalls = 0;
  int registerClientCalls = 0;
  int registerServiceProviderCalls = 0;
  int verifyRegistrationCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AuthOutcome> resolveStoredSession(CancelToken cancelToken) {
    resolveCalls++;
    return onResolve(cancelToken);
  }

  @override
  Future<AuthOutcome> signInWithEmail(
    String email,
    String password,
    CancelToken cancelToken,
  ) {
    signInCalls++;
    return onSignIn?.call(email, password, cancelToken) ??
        Future.value(const CancelledSignIn());
  }

  @override
  Future<ChallengeOutcome> requestPhoneSignInCode(
    String phoneNumber,
    CancelToken cancelToken, {
    PhoneSignInActor actor = PhoneSignInActor.client,
  }) {
    lastPhoneActor = actor;
    requestClientCodeCalls++;
    return onRequestClientCode?.call(phoneNumber, cancelToken) ??
        Future.value(
          const ChallengeFailure('No fake Client-code response configured.'),
        );
  }

  @override
  Future<AuthOutcome> verifyPhoneSignInCode(
    String challengeId,
    String code,
    CancelToken cancelToken, {
    PhoneSignInActor actor = PhoneSignInActor.client,
  }) {
    lastPhoneActor = actor;
    verifyClientCodeCalls++;
    return onVerifyClientCode?.call(challengeId, code, cancelToken) ??
        Future.value(const CancelledSignIn());
  }

  @override
  Future<ChallengeOutcome> resendPhoneSignInCode(
    String challengeId,
    CancelToken cancelToken, {
    PhoneSignInActor actor = PhoneSignInActor.client,
  }) =>
      onResendClientCode?.call(challengeId, cancelToken) ??
      Future.value(
        const ChallengeFailure('No fake resend response configured.'),
      );

  @override
  Future<ChallengeOutcome> registerClient(
    ClientRegistrationRequest request,
    CancelToken cancelToken,
  ) {
    registerClientCalls++;
    return onRegisterClient?.call(request, cancelToken) ??
        Future.value(
          const ChallengeFailure('No fake registration response configured.'),
        );
  }

  @override
  Future<ChallengeOutcome> registerServiceProvider(
    ServiceProviderRegistrationRequest request,
    CancelToken cancelToken,
  ) {
    registerServiceProviderCalls++;
    return onRegisterServiceProvider?.call(request, cancelToken) ??
        Future.value(
          const ChallengeFailure('No fake registration response configured.'),
        );
  }

  @override
  Future<AuthOutcome> verifyRegistration(
    String challengeId,
    String code,
    CancelToken cancelToken,
  ) {
    verifyRegistrationCalls++;
    return onVerifyRegistration?.call(challengeId, code, cancelToken) ??
        Future.value(const CancelledSignIn());
  }

  @override
  Future<ChallengeOutcome> resendRegistrationCode(
    String challengeId,
    CancelToken cancelToken,
  ) =>
      onResendRegistrationCode?.call(challengeId, cancelToken) ??
      Future.value(
        const ChallengeFailure('No fake resend response configured.'),
      );

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
