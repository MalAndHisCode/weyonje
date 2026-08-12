import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weyonje/app.dart';
import 'package:weyonje/core/auth/auth_providers.dart';
import 'package:weyonje/core/auth/auth_repository.dart';

import '../support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
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
