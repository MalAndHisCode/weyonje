import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/current_actor.dart';
import '../core/auth/registration_models.dart';
import '../features/auth/application/launch_controller.dart';
import '../features/auth/presentation/access_denied_screen.dart';
import '../features/auth/presentation/authorized_destination_unavailable_screen.dart';
import '../features/auth/presentation/choose_account_type_screen.dart';
import '../features/auth/presentation/client_phone_sign_in_screen.dart';
import '../features/auth/presentation/client_registration_screen.dart';
import '../features/auth/presentation/phone_verification_screen.dart';
import '../features/auth/presentation/provider_account_status_screen.dart';
import '../features/auth/presentation/service_provider_registration_screen.dart';
import '../features/auth/presentation/session_check_screen.dart';
import '../features/auth/presentation/session_error_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';

abstract final class AppRoutes {
  static const launch = '/launch';
  static const welcome = '/welcome';
  static const chooseAccountType = '/account-type';
  static const signIn = '/sign-in';
  static const clientSignIn = '/sign-in/client';
  static const clientRegistration = '/register/client';
  static const serviceProviderRegistration = '/register/service-provider';
  static const phoneVerification = '/verify-phone';
  static const sessionError = '/session-error';
  static const accessDenied = '/access-denied';
  static const providerAccountStatus = '/provider-account-status';
  static const clientHome = '/client';
  static const providerHome = '/provider';
  static const kccaMonitoring = '/kcca-monitoring';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen<LaunchState>(launchControllerProvider, (_, _) => refresh.notify());
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: AppRoutes.launch,
    refreshListenable: refresh,
    redirect: (context, routeState) =>
        _redirect(ref.read(launchControllerProvider), routeState.uri.path),
    routes: [
      GoRoute(
        path: AppRoutes.launch,
        builder: (context, state) => const SessionCheckScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.chooseAccountType,
        builder: (context, state) => const ChooseAccountTypeScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.clientSignIn,
        builder: (context, state) => const ClientPhoneSignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.clientRegistration,
        builder: (context, state) => const ClientRegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.serviceProviderRegistration,
        builder: (context, state) => const ServiceProviderRegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.phoneVerification,
        redirect: (context, state) => state.extra is PhoneVerificationArguments
            ? null
            : AppRoutes.welcome,
        builder: (context, state) => PhoneVerificationScreen(
          arguments: state.extra! as PhoneVerificationArguments,
        ),
      ),
      GoRoute(
        path: AppRoutes.sessionError,
        builder: (context, state) => const SessionErrorScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessDenied,
        builder: (context, state) => const AccessDeniedScreen(),
      ),
      GoRoute(
        path: AppRoutes.providerAccountStatus,
        builder: (context, state) => const ProviderAccountStatusScreen(),
      ),
      GoRoute(
        path: AppRoutes.clientHome,
        builder: (context, state) =>
            const AuthorizedDestinationUnavailableScreen(
              destinationName: 'Client dashboard',
            ),
      ),
      GoRoute(
        path: AppRoutes.providerHome,
        builder: (context, state) =>
            const AuthorizedDestinationUnavailableScreen(
              destinationName: 'Provider work dashboard',
            ),
      ),
      GoRoute(
        path: AppRoutes.kccaMonitoring,
        builder: (context, state) =>
            const AuthorizedDestinationUnavailableScreen(
              destinationName: 'KCCA monitoring dashboard',
            ),
      ),
    ],
  );
});

String? _redirect(LaunchState launch, String path) {
  return switch (launch) {
    LaunchChecking() => path == AppRoutes.launch ? null : AppRoutes.launch,
    LaunchTransientError() =>
      path == AppRoutes.sessionError ? null : AppRoutes.sessionError,
    LaunchUnauthenticated() =>
      _isUnauthenticatedPath(path) ? null : AppRoutes.welcome,
    LaunchAccessDenied() =>
      path == AppRoutes.accessDenied ? null : AppRoutes.accessDenied,
    LaunchAuthenticated(:final actor) => _authenticatedRedirect(actor, path),
  };
}

bool _isUnauthenticatedPath(String path) =>
    path == AppRoutes.welcome ||
    path == AppRoutes.chooseAccountType ||
    path == AppRoutes.signIn ||
    path == AppRoutes.clientSignIn ||
    path == AppRoutes.phoneVerification ||
    path == AppRoutes.clientRegistration ||
    path == AppRoutes.serviceProviderRegistration;

String? _authenticatedRedirect(CurrentActor actor, String path) {
  final destination = switch ((actor.actorType, actor.access)) {
    (ActorType.serviceProvider, ActorAccess.restricted) =>
      AppRoutes.providerAccountStatus,
    (_, ActorAccess.denied) => AppRoutes.accessDenied,
    (ActorType.client, ActorAccess.eligible) => AppRoutes.clientHome,
    (ActorType.serviceProvider, ActorAccess.eligible) => AppRoutes.providerHome,
    (ActorType.kccaStaff, ActorAccess.eligible) => AppRoutes.kccaMonitoring,
    _ => AppRoutes.accessDenied,
  };
  return path == destination ? null : destination;
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
