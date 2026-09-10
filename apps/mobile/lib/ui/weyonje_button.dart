import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

enum WeyonjeButtonKind { primary, secondary, outline }

class WeyonjeButton extends StatelessWidget {
  const WeyonjeButton({
    required this.label,
    required this.onPressed,
    this.kind = WeyonjeButtonKind.primary,
    this.loading = false,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final WeyonjeButtonKind kind;
  final bool loading;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
    child: FButton(
      onPress: loading ? null : onPressed,
      autofocus: autofocus,
      semanticsLabel: label,
      variant: switch (kind) {
        WeyonjeButtonKind.primary => FButtonVariant.primary,
        WeyonjeButtonKind.secondary => FButtonVariant.secondary,
        WeyonjeButtonKind.outline => FButtonVariant.outline,
      },
      child: Flexible(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(label, textAlign: TextAlign.center)),
            if (loading) ...[
              const SizedBox(width: 12),
              SizedBox.square(
                dimension: 18,
                child: FCircularProgress(
                  style: FCircularProgressStyleDelta.delta(
                    iconStyle: IconThemeDataDelta.delta(
                      color: kind == WeyonjeButtonKind.primary
                          ? context.theme.colors.primaryForeground
                          : context.theme.colors.secondaryForeground,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
