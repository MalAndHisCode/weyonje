import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weyonje/app.dart';
import 'package:weyonje/core/auth/auth_providers.dart';
import 'package:weyonje/core/auth/auth_repository.dart';
import 'package:weyonje/core/auth/current_actor.dart';

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
        expect(find.text('Sign in'), findsOneWidget);
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
      expect(find.text('Choose an account type'), findsOneWidget);

      await tester.tap(find.byKey(const Key('account-client')));
      await tester.tap(find.byKey(const Key('account-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Registration is not available'), findsOneWidget);
      expect(
        find.textContaining('No account information has been collected'),
        findsOneWidget,
      );
    });

    testWidgets(
      'opens native AUTH-003 and completes sign-in through the repository boundary',
      (tester) async {
        final repository = FakeAuthRepository(
          onResolve: (_) async => const NoStoredSession(),
          onSignIn: (_, _, _) async => const ResolvedSession(
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
        expect(find.text('Client dashboard unavailable'), findsWidgets);
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
      await tester.ensureVisible(find.byKey(const Key('sign-in')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sign-in')));
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
        await tester.tap(find.byKey(const Key('sign-in')));
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
      await tester.tap(find.byKey(const Key('sign-in')));
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
                  ? 'Client dashboard unavailable'
                  : 'KCCA monitoring dashboard unavailable',
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
        expect(find.text('Provider work dashboard unavailable'), findsWidgets);
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
