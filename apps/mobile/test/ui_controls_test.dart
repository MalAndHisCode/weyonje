import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:weyonje/theme/theme.dart';
import 'package:weyonje/ui/weyonje_button.dart';
import 'package:weyonje/ui/weyonje_dialog.dart';
import 'package:weyonje/ui/weyonje_select.dart';

void main() {
  Future<void> render(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: lightTheme.toApproximateMaterialTheme(),
      builder: (context, child) => FTheme(data: lightTheme, child: child!),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    ),
  );

  testWidgets('shared selection preserves values and required validation', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    String? selected;
    await render(
      tester,
      Form(
        key: form,
        child: WeyonjeSelect<String>(
          label: const Text('Provider'),
          items: const [
            (value: 'one', label: 'Same name'),
            (value: 'two', label: 'Same name'),
          ],
          onChanged: (value) => selected = value,
          validator: (value) => value == null ? 'Choose a provider.' : null,
        ),
      ),
    );
    expect(form.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Choose a provider.'), findsOneWidget);
    await tester.tap(find.byType(FTextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Same name').last);
    await tester.pumpAndSettle();
    expect(selected, 'two');
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets('mobile controls retain touch sizing and loading lockout', (
    tester,
  ) async {
    var presses = 0;
    await render(
      tester,
      Column(
        children: [
          WeyonjeButton(
            label: 'Submit Request',
            loading: true,
            onPressed: () => presses++,
          ),
          FButton(onPress: () => presses++, child: const Text('Cancel')),
          FRadio(label: const Text('Option'), onChange: (_) {}),
          FSwitch(label: const Text('Enabled'), onChange: (_) {}),
        ],
      ),
    );
    for (final button in find.byType(FButton).evaluate()) {
      expect(
        tester.getSize(find.byWidget(button.widget)).height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(
      tester.getSize(find.byType(FRadio)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(FSwitch)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      lightTheme.textFieldStyles
          .resolve({FTextFieldSizeVariant.md})
          .constraints
          .minHeight,
      48,
    );
    expect(
      lightTheme.selectStyle.fieldStyles
          .resolve({FTextFieldSizeVariant.md})
          .constraints
          .minHeight,
      48,
    );
    await tester.tap(find.text('Submit Request'));
    expect(presses, 0);
    await tester.tap(find.text('Cancel'));
    expect(presses, 1);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('shared dialog scrolls above a keyboard at enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await render(
      tester,
      Builder(
        builder: (context) => WeyonjeButton(
          label: 'Open',
          onPressed: () => showFDialog<void>(
            context: context,
            useSafeArea: true,
            builder: (context, _, _) => WeyonjeDialog(
              title: const Text('Confirm Provider Status'),
              content: const FTextField(label: Text('Reason'), maxLines: 3),
              actions: [
                WeyonjeButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Provider Status'), findsNothing);
  });
}
