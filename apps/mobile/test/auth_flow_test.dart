import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:weyonje/app.dart';
import 'package:weyonje/core/auth/auth_providers.dart';
import 'package:weyonje/core/auth/auth_repository.dart';
import 'package:weyonje/core/auth/current_actor.dart';
import 'package:weyonje/core/auth/registration_models.dart';

import 'support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(
    WidgetTester tester,
    FakeAuthRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const WeyonjeApplication(),
      ),
    );
  }

  group('AUTH-001 unauthenticated experience', () {
    testWidgets(
      'renders the approved identity, copy, actions, and no staff registration',
      (tester) async {
        final repository = FakeAuthRepository(
          onResolve: (_) async => const NoStoredSession(),
        );
        await pumpApp(tester, repository);
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsOneWidget);
        expect(find.text('Welcome to Weyonje'), findsOneWidget);
        expect(find.text('Create account'), findsOneWidget);
        expect(find.text('Client sign in'), findsOneWidget);
        expect(find.text('Provider or KCCA sign in'), findsOneWidget);
        expect(find.textContaining('KCCA Staff'), findsNothing);

        final semantics = tester.getSemantics(find.byType(Image));
        expect(semantics.label, 'Weyonje');
        expect(
          tester.getSize(find.byKey(const Key('create-account'))).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSize(find.byKey(const Key('sign-in'))).height,
          greaterThanOrEqualTo(48),
        );
      },
    );

    testWidgets('opens AUTH-002 and validates account-type selection', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-account')));
      await tester.pumpAndSettle();

      expect(find.text('Choose account type'), findsOneWidget);
      expect(find.text('Client'), findsOneWidget);
      expect(find.text('Service Provider'), findsOneWidget);
      expect(find.textContaining('KCCA Staff'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Weyonje'), findsOneWidget);
      await tester.tap(find.byKey(const Key('create-account')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('account-continue')));
      await tester.pump();
      expect(find.text('Account type required'), findsOneWidget);

      await tester.tap(find.byKey(const Key('account-client')));
      await tester.tap(find.byKey(const Key('account-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Client registration'), findsOneWidget);
      expect(find.byKey(const Key('client-type-individual')), findsOneWidget);
      expect(find.text('Email address (optional)'), findsOneWidget);
    });

    testWidgets(
      'AUTH-002 exposes two exclusive semantic choices and opens Provider registration',
      (tester) async {
        final repository = FakeAuthRepository(
          onResolve: (_) async => const NoStoredSession(),
        );
        await pumpApp(tester, repository);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('create-account')));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel('Client. Request waste-collection services.'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            'Service Provider. Receive and handle service requests after satisfying KCCA approval requirements.',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<FRadio>(find.byKey(const Key('account-client'))).value,
          isFalse,
        );
        expect(
          tester
              .widget<FRadio>(find.byKey(const Key('account-provider')))
              .value,
          isFalse,
        );
        expect(
          tester.getSize(find.byKey(const Key('account-client'))).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSize(find.byKey(const Key('account-provider'))).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSize(find.byKey(const Key('account-continue'))).height,
          greaterThanOrEqualTo(48),
        );

        await tester.tap(find.byKey(const Key('account-client')));
        await tester.pump();
        expect(
          tester.widget<FRadio>(find.byKey(const Key('account-client'))).value,
          isTrue,
        );
        final selectedClientSemantics = tester.getSemantics(
          find.bySemanticsLabel('Client. Request waste-collection services.'),
        );
        expect(
          selectedClientSemantics.flagsCollection.isChecked,
          CheckedState.isTrue,
        );
        await tester.tap(find.byKey(const Key('account-provider')));
        await tester.pump();
        expect(
          tester.widget<FRadio>(find.byKey(const Key('account-client'))).value,
          isFalse,
        );
        expect(
          tester
              .widget<FRadio>(find.byKey(const Key('account-provider')))
              .value,
          isTrue,
        );

        await tester.tap(find.byKey(const Key('account-continue')));
        await tester.pumpAndSettle();
        expect(find.text('Service Provider registration'), findsOneWidget);
        expect(find.text('Email address (required)'), findsOneWidget);
        expect(find.text('Password (required)'), findsOneWidget);
      },
    );

    testWidgets('AUTH-002 suppresses repeated Continue navigation', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-client')));
      await tester.tap(find.byKey(const Key('account-continue')));
      await tester.tap(find.byKey(const Key('account-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Client registration'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Choose account type'), findsOneWidget);
    });

    testWidgets('invalid verification route data fails safely', (tester) async {
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      GoRouter.of(
        tester.element(find.text('Welcome to Weyonje')),
      ).go('/verify-phone');
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Weyonje'), findsOneWidget);
      expect(find.text('Verify phone number'), findsNothing);
    });

    testWidgets('Client sign in requests and verifies an SMS code', (
      tester,
    ) async {
      final challenge = PhoneChallenge(
        id: '73f3d97e-0f93-445d-bdbe-77abac7b42ac',
        maskedPhone: '+256 •••••• 123',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        resendAvailableAt: DateTime.now().toUtc(),
        deliveryStatus: PhoneCodeDeliveryStatus.sent,
      );
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onRequestClientCode: (_, _) async => ChallengeCreated(challenge),
        onVerifyClientCode: (_, _, _) async => const ResolvedSession(
          CurrentActor(
            actorType: ActorType.client,
            access: ActorAccess.eligible,
          ),
        ),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sign-in')));
      await tester.pumpAndSettle();
      expect(find.text('Client sign in'), findsWidgets);
      expect(find.text('Password'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('client-sign-in-phone')),
        '0700000123',
      );
      await tester.tap(find.byKey(const Key('request-client-code')));
      await tester.pumpAndSettle();
      expect(repository.requestClientCodeCalls, 1);
      expect(find.text('Verify phone number'), findsOneWidget);
      expect(find.textContaining('+256'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('verification-code')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('verify-phone')));
      await tester.pumpAndSettle();
      expect(repository.verifyClientCodeCalls, 1);
      expect(find.text('Client dashboard'), findsWidgets);
    });

    testWidgets('development SMS code is displayed and prefilled', (
      tester,
    ) async {
      final challenge = PhoneChallenge(
        id: '3284667f-f025-4db1-9849-f92823b6748c',
        maskedPhone: '+256 •••••• 123',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        resendAvailableAt: DateTime.now().toUtc(),
        deliveryStatus: PhoneCodeDeliveryStatus.sent,
        developmentVerificationCode: '654321',
      );
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onRequestClientCode: (_, _) async => ChallengeCreated(challenge),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sign-in')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('client-sign-in-phone')),
        '0700000123',
      );
      await tester.tap(find.byKey(const Key('request-client-code')));
      await tester.pumpAndSettle();

      expect(find.text('Development SMS mode'), findsOneWidget);
      expect(
        find.text(
          'No SMS was sent. Use test code 654321; it has been filled in below.',
        ),
        findsOneWidget,
      );
      final codeField = tester.widget<TextFormField>(
        find.byKey(const Key('verification-code')),
      );
      expect(codeField.controller?.text, '654321');
    });

    testWidgets(
      'Client registration preserves optional email and reaches verification',
      (tester) async {
        ClientRegistrationRequest? submitted;
        final challenge = PhoneChallenge(
          id: '3efeb8db-3692-47ab-85f1-3890339ac322',
          maskedPhone: '+256 •••••• 123',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
          resendAvailableAt: DateTime.now().toUtc(),
          deliveryStatus: PhoneCodeDeliveryStatus.sent,
        );
        final repository = FakeAuthRepository(
          onResolve: (_) async => const NoStoredSession(),
          onRegisterClient: (request, _) async {
            submitted = request;
            return ChallengeCreated(challenge);
          },
        );
        await pumpApp(tester, repository);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('create-account')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('account-client')));
        await tester.tap(find.byKey(const Key('account-continue')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('client-type-individual')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('client-first-name')),
          'Amina',
        );
        await tester.enterText(find.byKey(const Key('client-last-name')), 'N.');
        await tester.enterText(
          find.byKey(const Key('client-phone')),
          '0700000123',
        );
        await tester.ensureVisible(
          find.byKey(const Key('submit-client-registration')),
        );
        await tester.tap(find.byKey(const Key('submit-client-registration')));
        await tester.pumpAndSettle();
        expect(repository.registerClientCalls, 1);
        expect(submitted?.email, isNull);
        expect(submitted?.clientType, ClientType.individual);
        expect(find.text('Verify phone number'), findsOneWidget);
      },
    );

    testWidgets(
      'Provider registration requires email and submits the full approval profile',
      (tester) async {
        ServiceProviderRegistrationRequest? submitted;
        final challenge = PhoneChallenge(
          id: '90a62e5a-4c95-4cd1-ab43-bb18ed3c7402',
          maskedPhone: '+256 •••••• 123',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
          resendAvailableAt: DateTime.now().toUtc(),
          deliveryStatus: PhoneCodeDeliveryStatus.sent,
        );
        final repository = FakeAuthRepository(
          onResolve: (_) async => const NoStoredSession(),
          onRegisterServiceProvider: (request, _) async {
            submitted = request;
            return ChallengeCreated(challenge);
          },
        );
        await pumpApp(tester, repository);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('create-account')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('account-provider')));
        await tester.tap(find.byKey(const Key('account-continue')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('provider-ess-license')),
          'ESS-42',
        );
        await tester.enterText(
          find.byKey(const Key('provider-company-name')),
          'Clean Kampala Ltd',
        );
        await tester.enterText(
          find.byKey(const Key('provider-phone')),
          '0700000123',
        );
        await tester.enterText(
          find.byKey(const Key('provider-email')),
          'ops@example.test',
        );
        await tester.enterText(
          find.byKey(const Key('provider-password')),
          'a-long-test-password',
        );
        await tester.enterText(
          find.byKey(const Key('provider-confirm-password')),
          'a-long-test-password',
        );
        await tester.enterText(
          find.byKey(const Key('provider-work-address')),
          'Nakawa',
        );
        await tester.ensureVisible(find.byKey(const Key('provider-type')));
        await tester.tap(find.byKey(const Key('provider-type')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Gulper').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('provider-contact-name')),
          'Amina',
        );
        await tester.enterText(
          find.byKey(const Key('provider-contact-phone')),
          '0701000123',
        );
        await tester.ensureVisible(
          find.byKey(const Key('submit-provider-registration')),
        );
        await tester.tap(find.byKey(const Key('submit-provider-registration')));
        await tester.pumpAndSettle();

        expect(repository.registerServiceProviderCalls, 1);
        expect(submitted?.email, 'ops@example.test');
        expect(submitted?.providerType, ServiceProviderType.gulper);
        expect(find.text('Verify phone number'), findsOneWidget);
      },
    );

    testWidgets(
      'opens native AUTH-003 and completes sign-in through the repository boundary',
      (tester) async {
        final repository = FakeAuthRepository(
          onResolve: (_) async => const NoStoredSession(),
          onSignIn: (_, _, _) async => const ResolvedSession(
            CurrentActor(
              actorType: ActorType.serviceProvider,
              access: ActorAccess.eligible,
              providerStatus: ProviderStatus.approved,
            ),
          ),
        );
        await pumpApp(tester, repository);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('staff-sign-in')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('staff-sign-in')));
        await tester.pumpAndSettle();

        expect(find.text('Email address'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        final passwordField = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const Key('sign-in-password')),
            matching: find.byType(EditableText),
          ),
        );
        expect(passwordField.obscureText, isTrue);
        expect(find.textContaining('browser'), findsNothing);
        expect(find.textContaining('Keycloak'), findsNothing);
        await tester.enterText(
          find.byKey(const Key('sign-in-email')),
          'account@example.test',
        );
        await tester.enterText(
          find.byKey(const Key('sign-in-password')),
          'not-a-real-password',
        );
        await tester.tap(find.byKey(const Key('submit-sign-in')));
        await tester.pumpAndSettle();
        expect(repository.signInCalls, 1);
        expect(find.text('Provider work dashboard'), findsWidgets);
      },
    );

    testWidgets('keeps native sign-in controls reachable above the keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('staff-sign-in')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-sign-in')));
      await tester.pumpAndSettle();

      await tester.showKeyboard(find.byKey(const Key('sign-in-password')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('submit-sign-in')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('submit-sign-in')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'prevents duplicate sign-in and preserves the loading control',
      (tester) async {
        final result = Completer<AuthOutcome>();
        final repository = FakeAuthRepository(
          onResolve: (_) async => const NoStoredSession(),
          onSignIn: (_, _, _) => result.future,
        );
        await pumpApp(tester, repository);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('staff-sign-in')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('staff-sign-in')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('sign-in-email')),
          'account@example.test',
        );
        await tester.enterText(
          find.byKey(const Key('sign-in-password')),
          'not-a-real-password',
        );
        final before = tester.getSize(find.byKey(const Key('submit-sign-in')));
        await tester.tap(find.byKey(const Key('submit-sign-in')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('submit-sign-in')));
        await tester.pump();

        expect(repository.signInCalls, 1);
        expect(find.text('Sign in'), findsWidgets);
        expect(tester.getSize(find.byKey(const Key('submit-sign-in'))), before);

        result.complete(
          const RateLimitedAuthFailure(
            'Too many sign-in attempts. Wait briefly and try again.',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Try again shortly'), findsOneWidget);
      },
    );

    testWidgets('shows a recoverable connection failure on native sign-in', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onSignIn: (_, _, _) async => const TransientAuthFailure(
          'Weyonje could not sign you in. Check your connection and try again.',
        ),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('staff-sign-in')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-sign-in')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('sign-in-email')),
        'account@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('sign-in-password')),
        'not-a-real-password',
      );
      await tester.tap(find.byKey(const Key('submit-sign-in')));
      await tester.pumpAndSettle();

      expect(find.text('Sign-in not completed'), findsOneWidget);
      expect(find.textContaining('Check your connection'), findsOneWidget);
    });
  });

  group('launch and session resolution', () {
    testWidgets('restarts a cancelled initial check when the app resumes', (
      tester,
    ) async {
      final first = Completer<AuthOutcome>();
      var calls = 0;
      final repository = FakeAuthRepository(
        onResolve: (cancelToken) {
          if (calls == 0) {
            calls++;
            return first.future;
          }
          calls++;
          return Future.value(const NoStoredSession());
        },
      );
      await pumpApp(tester, repository);
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repository.resolveCalls, 2);
      expect(find.text('Welcome to Weyonje'), findsOneWidget);
      first.complete(const CancelledSignIn());
    });

    testWidgets('shows a stable loading state and no protected-content flash', (
      tester,
    ) async {
      final result = Completer<AuthOutcome>();
      final repository = FakeAuthRepository(onResolve: (_) => result.future);
      await pumpApp(tester, repository);
      await tester.pump();

      expect(find.text('Checking your session…'), findsOneWidget);
      expect(find.textContaining('dashboard'), findsNothing);
      expect(find.text('Create account'), findsNothing);
      result.complete(const NoStoredSession());
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Weyonje'), findsOneWidget);
    });

    testWidgets(
      'returns an expired session safely to account access with feedback',
      (tester) async {
        final repository = FakeAuthRepository(
          onResolve: (_) async =>
              const InvalidSession('Your session has expired. Sign in again.'),
        );
        await pumpApp(tester, repository);
        await tester.pumpAndSettle();
        expect(find.text('Welcome to Weyonje'), findsOneWidget);
        expect(
          find.text('Your session has expired. Sign in again.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'preserves a transient session and prevents duplicate retries',
      (tester) async {
        final retry = Completer<AuthOutcome>();
        var first = true;
        final repository = FakeAuthRepository(
          onResolve: (_) {
            if (first) {
              first = false;
              return Future.value(
                const TransientAuthFailure(
                  'Connection unavailable. Retry safely.',
                ),
              );
            }
            return retry.future;
          },
        );
        await pumpApp(tester, repository);
        await tester.pumpAndSettle();
        expect(
          find.text('Connection unavailable. Retry safely.'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('retry-session')));
        await tester.tap(find.byKey(const Key('retry-session')));
        await tester.pump();
        expect(repository.resolveCalls, 2);
        expect(find.text('Retry session check'), findsOneWidget);
        retry.complete(const NoStoredSession());
        await tester.pumpAndSettle();
        expect(find.text('Welcome to Weyonje'), findsOneWidget);
      },
    );

    testWidgets('routes unknown profiles to a safe access-denied state', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        onResolve: (_) async => const DeniedSession(
          'This identity is not linked to a permitted profile.',
        ),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      expect(find.text('Access denied'), findsOneWidget);
      expect(
        find.text('This identity is not linked to a permitted profile.'),
        findsOneWidget,
      );
      expect(find.textContaining('dashboard'), findsNothing);
    });
  });

  group('role and provider eligibility routing', () {
    testWidgets('authenticated users cannot enter AUTH-002', (tester) async {
      final repository = FakeAuthRepository(
        onResolve: (_) async => const ResolvedSession(
          CurrentActor(
            actorType: ActorType.client,
            access: ActorAccess.eligible,
          ),
        ),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Client dashboard').first);
      GoRouter.of(context).go('/account-type');
      await tester.pumpAndSettle();
      expect(find.text('Choose account type'), findsNothing);
      expect(find.text('Client dashboard'), findsWidgets);
    });

    testWidgets(
      'routes eligible Client and KCCA sessions to their authorized boundaries',
      (tester) async {
        for (final actor in [
          const CurrentActor(
            actorType: ActorType.client,
            access: ActorAccess.eligible,
          ),
          const CurrentActor(
            actorType: ActorType.kccaStaff,
            access: ActorAccess.eligible,
          ),
        ]) {
          final repository = FakeAuthRepository(
            onResolve: (_) async => ResolvedSession(actor),
          );
          await pumpApp(tester, repository);
          await tester.pumpAndSettle();
          expect(
            find.text(
              actor.actorType == ActorType.client
                  ? 'Client dashboard'
                  : 'KCCA monitoring',
            ),
            findsWidgets,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );

    testWidgets(
      'routes an approved active Provider only to the provider boundary',
      (tester) async {
        final repository = FakeAuthRepository(
          onResolve: (_) async => const ResolvedSession(
            CurrentActor(
              actorType: ActorType.serviceProvider,
              access: ActorAccess.eligible,
              providerStatus: ProviderStatus.approved,
            ),
          ),
        );
        await pumpApp(tester, repository);
        await tester.pumpAndSettle();
        expect(find.text('Provider work dashboard'), findsWidgets);
      },
    );

    testWidgets('never routes an unpermitted KCCA account to monitoring', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        onResolve: (_) async => const ResolvedSession(
          CurrentActor(
            actorType: ActorType.kccaStaff,
            access: ActorAccess.denied,
          ),
        ),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      expect(find.text('Access denied'), findsOneWidget);
      expect(find.textContaining('monitoring dashboard'), findsNothing);
    });

    for (final status in [
      ProviderStatus.pending,
      ProviderStatus.rejected,
      ProviderStatus.inactive,
      ProviderStatus.disabled,
    ]) {
      testWidgets('never routes a ${status.name} Provider to provider work', (
        tester,
      ) async {
        final repository = FakeAuthRepository(
          onResolve: (_) async => ResolvedSession(
            CurrentActor(
              actorType: ActorType.serviceProvider,
              access: ActorAccess.restricted,
              providerStatus: status,
            ),
          ),
        );
        await pumpApp(tester, repository);
        await tester.pumpAndSettle();
        expect(find.text('Account status'), findsOneWidget);
        expect(find.textContaining('Provider work dashboard'), findsNothing);
      });
    }

    testWidgets('shows the KCCA rejection reason to a rejected Provider', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        onResolve: (_) async => const ResolvedSession(
          CurrentActor(
            actorType: ActorType.serviceProvider,
            access: ActorAccess.restricted,
            providerStatus: ProviderStatus.rejected,
            providerRejectionReason: 'ESS licence could not be validated.',
          ),
        ),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('ESS licence could not be validated.'),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'long errors remain reachable at large text scale on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final repository = FakeAuthRepository(
        onResolve: (_) async => const TransientAuthFailure(
          'Weyonje could not verify your session because the identity service is temporarily unavailable. Check your connection and retry.',
        ),
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('retry-session')));
      expect(find.byKey(const Key('retry-session')), findsOneWidget);
    },
  );
}
