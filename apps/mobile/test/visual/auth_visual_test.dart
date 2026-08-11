import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weyonje/app.dart';
import 'package:weyonje/core/auth/auth_providers.dart';
import 'package:weyonje/core/auth/auth_repository.dart';

import '../support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> render(
    WidgetTester tester, {
    required Size size,
    required AuthOutcome outcome,
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
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(onResolve: (_) async => outcome),
          ),
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
    await tester.ensureVisible(find.byKey(const Key('sign-in')));
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
}
