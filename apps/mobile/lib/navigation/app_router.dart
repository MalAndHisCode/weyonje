import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/current_actor.dart';
import '../core/auth/registration_models.dart';
import '../features/auth/application/launch_controller.dart';
import '../features/auth/presentation/access_denied_screen.dart';
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
import '../features/auth/presentation/account_security_screens.dart';
import '../features/workflows/presentation/client_request_screens.dart';
import '../features/workflows/presentation/dashboard_screens.dart';
import '../features/workflows/presentation/provider_screens.dart';
import '../features/workflows/presentation/tracking_screen.dart';
import '../features/workflows/presentation/kcca_admin_screens.dart';

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
  static const clientRequestNew = '/client/requests/new';
  static const clientRequests = '/client/requests';
  static const locationPicker = '/client/location-picker';
  static const providerPending = '/provider/requests/pending';
  static const providerJobs = '/provider/jobs';
  static const notifications = '/notifications';
  static const passwordRecovery = '/account/recover';
  static const emailVerification = '/account/verify-email';
  static const kccaProviderAdministration = '/kcca/providers';
  static const kccaCallCentre = '/kcca/call-centre';
  static const kccaDisposalSites = '/kcca/disposal-sites';
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
        path: AppRoutes.passwordRecovery,
        builder: (context, state) => const PasswordRecoveryScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (context, state) => EmailVerificationScreen(
          initialChallengeId: state.uri.queryParameters['challengeId'],
          initialCode: state.uri.queryParameters['code'],
        ),
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
        builder: (context, state) => const ClientDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.providerHome,
        builder: (context, state) => const ProviderDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.kccaMonitoring,
        builder: (context, state) => const KccaMonitoringDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.kccaProviderAdministration,
        builder: (context, state) => const ProviderAdministrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.kccaCallCentre,
        builder: (context, state) => const CallCentreAdministrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.kccaDisposalSites,
        builder: (context, state) => const DisposalSiteAdministrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.clientRequestNew,
        builder: (context, state) => const RequestServiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.locationPicker,
        builder: (context, state) => const RequestLocationPickerScreen(),
      ),
      GoRoute(
        path: AppRoutes.clientRequests,
        builder: (context, state) => const ClientRequestsScreen(),
      ),
      GoRoute(
        path: '/client/requests/:requestId',
        builder: (context, state) => ClientRequestDetailsScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/client/requests/:requestId/feedback',
        builder: (context, state) => CollectionFeedbackScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.providerPending,
        builder: (context, state) => const PendingServiceRequestsScreen(),
      ),
      GoRoute(
        path: '/provider/requests/:requestId',
        builder: (context, state) => ProviderRequestDetailsScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.providerJobs,
        builder: (context, state) => const ProviderJobsScreen(),
      ),
      GoRoute(
        path: '/provider/jobs/:requestId',
        builder: (context, state) => ProviderJobDetailsScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/tracking/:requestId',
        builder: (context, state) => JourneyTrackingScreen(
          requestId: state.pathParameters['requestId']!,
          phase: state.uri.queryParameters['phase'] ?? 'TO_REQUEST',
          providerMode: state.uri.queryParameters['provider'] == 'true',
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
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
    path == AppRoutes.passwordRecovery ||
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
  final allowed = switch (actor.actorType) {
    ActorType.client =>
      path == AppRoutes.clientHome ||
          path.startsWith('/client/') ||
          path.startsWith('/tracking/') ||
          path == AppRoutes.notifications,
    ActorType.serviceProvider =>
      path == AppRoutes.providerHome ||
          path.startsWith('/provider/') ||
          path.startsWith('/tracking/') ||
          path == AppRoutes.notifications ||
          path == AppRoutes.emailVerification ||
          path == AppRoutes.providerAccountStatus,
    ActorType.kccaStaff =>
      path == AppRoutes.kccaMonitoring ||
          path == AppRoutes.emailVerification ||
          (path == AppRoutes.kccaProviderAdministration &&
              actor.providerApprovalPermitted) ||
          ((path == AppRoutes.kccaCallCentre ||
                  path == AppRoutes.kccaDisposalSites) &&
              actor.callCentreOperationsPermitted) ||
          path.startsWith('/tracking/') ||
          path == AppRoutes.notifications,
  };
  return allowed ? null : destination;
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
