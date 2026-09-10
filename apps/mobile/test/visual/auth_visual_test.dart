import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:weyonje/app.dart';
import 'package:weyonje/core/auth/auth_providers.dart';
import 'package:weyonje/core/auth/auth_repository.dart';
import 'package:weyonje/core/auth/current_actor.dart';
import 'package:weyonje/features/workflows/application/workflow_providers.dart';
import 'package:weyonje/features/workflows/data/workflow_repository.dart';
import 'package:weyonje/features/workflows/domain/workflow_models.dart';

import '../support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Load the fonts already bundled with the app so visual checks assess
    // readable typography rather than Flutter tests' default Ahem rectangles.
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font
          in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> renderRepository(
    WidgetTester tester, {
    required Size size,
    required FakeAuthRepository repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          workflowRepositoryProvider.overrideWithValue(_VisualWorkflows()),
        ],
        child: const WeyonjeApplication(),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/weyonje-logo.png'),
        tester.element(find.byType(WeyonjeApplication)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> render(
    WidgetTester tester, {
    required Size size,
    required AuthOutcome outcome,
  }) async {
    await renderRepository(
      tester,
      size: size,
      repository: FakeAuthRepository(onResolve: (_) async => outcome),
    );
  }

  Future<void> openNativeSignIn(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('staff-sign-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('staff-sign-in')));
    await tester.pumpAndSettle();
  }

  Future<void> openAccountType(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('create-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-account')));
    await tester.pumpAndSettle();
  }

  testWidgets('welcome remains balanced on a compact phone', (tester) async {
    await render(
      tester,
      size: const Size(360, 640),
      outcome: const NoStoredSession(),
    );
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/welcome_compact.png'),
    );
  });

  for (final entry in ['welcome', 'provider', 'kcca']) {
    for (final landscape in [false, true]) {
      testWidgets(
        '$entry at enlarged text ${landscape ? 'landscape' : 'portrait'}',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await render(
            tester,
            size: landscape ? const Size(640, 360) : const Size(320, 568),
            outcome: const NoStoredSession(),
          );
          final key = Key(
            entry == 'provider' ? 'staff-sign-in' : 'kcca-sign-in',
          );
          await tester.ensureVisible(find.byKey(key));
          if (entry != 'welcome') {
            await tester.tap(find.byKey(key));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.byKey(const Key('submit-sign-in')));
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(WeyonjeApplication),
            matchesGoldenFile(
              'goldens/${entry}_large_text_${landscape ? 'landscape' : 'portrait'}.png',
            ),
          );
        },
      );
    }
  }

  for (final actor in [
    const CurrentActor(
      actorType: ActorType.client,
      access: ActorAccess.eligible,
    ),
    const CurrentActor(
      actorType: ActorType.serviceProvider,
      access: ActorAccess.eligible,
      providerStatus: ProviderStatus.approved,
    ),
    const CurrentActor(
      actorType: ActorType.kccaStaff,
      access: ActorAccess.eligible,
      mobileMonitoringPermitted: true,
      providerApprovalPermitted: true,
      callCentreOperationsPermitted: true,
    ),
  ]) {
    testWidgets('${actor.actorType.name} dashboard uses shared Forui styling', (
      tester,
    ) async {
      await render(
        tester,
        size: const Size(360, 800),
        outcome: ResolvedSession(actor),
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(WeyonjeApplication),
        matchesGoldenFile('goldens/${actor.actorType.name}_dashboard.png'),
      );
    });
  }

  testWidgets('welcome uses the available space on a large phone', (
    tester,
  ) async {
    await render(
      tester,
      size: const Size(412, 915),
      outcome: const NoStoredSession(),
    );
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/welcome_large.png'),
    );
  });

  testWidgets('welcome remains scrollable in landscape', (tester) async {
    await render(
      tester,
      size: const Size(640, 360),
      outcome: const NoStoredSession(),
    );
    await tester.ensureVisible(find.byKey(const Key('staff-sign-in')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/welcome_landscape.png'),
    );
  });

  testWidgets('transient error is readable on a compact phone', (tester) async {
    await render(
      tester,
      size: const Size(360, 640),
      outcome: const TransientAuthFailure(
        'Weyonje could not verify your session. Check your connection and retry.',
      ),
    );
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/session_error_compact.png'),
    );
  });

  testWidgets('account choice is focused on a compact phone', (tester) async {
    await render(
      tester,
      size: const Size(360, 640),
      outcome: const NoStoredSession(),
    );
    await openAccountType(tester);
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/account_type_compact.png'),
    );
  });

  testWidgets('account choice shows one selected option on a large phone', (
    tester,
  ) async {
    await render(
      tester,
      size: const Size(412, 915),
      outcome: const NoStoredSession(),
    );
    await openAccountType(tester);
    await tester.tap(find.byKey(const Key('account-provider')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/account_type_selected_large.png'),
    );
  });

  testWidgets('account choice validation remains adjacent and actionable', (
    tester,
  ) async {
    await render(
      tester,
      size: const Size(360, 640),
      outcome: const NoStoredSession(),
    );
    await openAccountType(tester);
    await tester.tap(find.byKey(const Key('account-continue')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/account_type_error_compact.png'),
    );
  });

  testWidgets('account choice remains reachable in landscape', (tester) async {
    await render(
      tester,
      size: const Size(640, 360),
      outcome: const NoStoredSession(),
    );
    await openAccountType(tester);
    await tester.ensureVisible(find.byKey(const Key('account-continue')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/account_type_landscape.png'),
    );
  });

  testWidgets('account choice remains readable with large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await render(
      tester,
      size: const Size(360, 640),
      outcome: const NoStoredSession(),
    );
    await openAccountType(tester);
    await tester.ensureVisible(find.byKey(const Key('account-continue')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/account_type_large_text.png'),
    );
  });

  testWidgets('native sign-in uses the available large portrait space', (
    tester,
  ) async {
    await render(
      tester,
      size: const Size(412, 915),
      outcome: const NoStoredSession(),
    );
    await openNativeSignIn(tester);
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/sign_in_large.png'),
    );
  });

  testWidgets(
    'native sign-in remains reachable in a compact keyboard viewport',
    (tester) async {
      await render(
        tester,
        size: const Size(320, 568),
        outcome: const NoStoredSession(),
      );
      await openNativeSignIn(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('submit-sign-in')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WeyonjeApplication),
        matchesGoldenFile('goldens/sign_in_keyboard_compact.png'),
      );
    },
  );

  testWidgets('native sign-in error is stable on a compact phone', (
    tester,
  ) async {
    await renderRepository(
      tester,
      size: const Size(360, 640),
      repository: FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onSignIn: (_, _, _) async =>
            const InvalidSession('Email or password is incorrect.'),
      ),
    );
    await openNativeSignIn(tester);
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
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/sign_in_error_compact.png'),
    );
  });

  testWidgets('native sign-in loading keeps its label and dimensions', (
    tester,
  ) async {
    final pending = Completer<AuthOutcome>();
    await renderRepository(
      tester,
      size: const Size(360, 640),
      repository: FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onSignIn: (_, _, _) => pending.future,
      ),
    );
    await openNativeSignIn(tester);
    await tester.enterText(
      find.byKey(const Key('sign-in-email')),
      'account@example.test',
    );
    await tester.enterText(
      find.byKey(const Key('sign-in-password')),
      'not-a-real-password',
    );
    await tester.tap(find.byKey(const Key('submit-sign-in')));
    await tester.pump();
    await expectLater(
      find.byType(WeyonjeApplication),
      matchesGoldenFile('goldens/sign_in_loading_compact.png'),
    );
    pending.complete(const CancelledSignIn());
    await tester.pump(const Duration(milliseconds: 200));
  });
}

class _VisualWorkflows extends Fake implements WorkflowRepository {
  static final request = ServiceRequestSummary(
    id: 'visual-request',
    reference: 'WEY-001',
    origin: 'MOBILE',
    status: 'ACCEPTED',
    locationLabel: 'Kampala Central',
    scheduleMode: 'ASAP',
    updatedAt: DateTime.utc(2026, 9, 10),
  );
  Future<WorkflowDashboard> _dashboard() async => WorkflowDashboard(
    pendingCount: 2,
    activeCount: 1,
    actionRequiredCount: 1,
    recentRequests: [request],
  );
  @override
  Future<WorkflowDashboard> clientDashboard() => _dashboard();
  @override
  Future<WorkflowDashboard> providerDashboard() => _dashboard();
  @override
  Future<List<ServiceRequestSummary>> kccaMonitoring() async => [request];
}
