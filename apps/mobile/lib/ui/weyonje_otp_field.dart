import 'dart:math';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// A single editable value. Scale digit typography explicitly because Forui's
/// inline WidgetSpans otherwise scale the box geometry a second time.
class WeyonjeOtpField extends StatelessWidget {
  const WeyonjeOtpField({
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    this.invalid = false,
    this.verified = false,
    super.key,
  });
  final FOtpController controller;
  final VoidCallback onChanged;
  final bool enabled;
  final bool invalid;
  final bool verified;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final theme = context.theme;
      final media = MediaQuery.of(context);
      final statusColor = verified
          ? theme.colors.primary
          : invalid
          ? theme.colors.error
          : theme.colors.border;
      FOtpFieldItemStyle item(Color border) => FOtpFieldItemStyle(
        decoration: BoxDecoration(
          color: theme.colors.card,
          border: Border.all(color: border, width: 1.5),
        ),
        contentTextStyle: theme.typography.body.lg.copyWith(
          fontSize: min(
            36,
            media.textScaler.scale(theme.typography.body.lg.fontSize ?? 18),
          ),
          color: verified || invalid ? statusColor : theme.colors.foreground,
        ),
      );
      final style = theme.otpFieldStyle.copyWith(
        itemSize: Size(min(48, bounds.maxWidth / 6), 56),
        itemStyles: FOtpFieldItemStyles(
          FVariants(
            item(statusColor),
            variants: {
              if (!verified && !invalid)
                [FOtpFieldItemVariant.focused]: item(theme.colors.primary),
            },
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExcludeSemantics(child: Text('Six-digit verification code')),
          const SizedBox(height: 8),
          MediaQuery(
            data: media.copyWith(textScaler: TextScaler.noScaling),
            child: Semantics(
              label: 'Six-digit verification code',
              child: FOtpField(
                key: const Key('verification-code'),
                control: FOtpFieldControl.managed(
                  controller: controller,
                  onChange: (_) => onChanged(),
                ),
                style: style,
                enabled: enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                enableIMEPersonalizedLearning: false,
                autofillHints: const [AutofillHints.oneTimeCode],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter or paste the code. It is checked automatically.',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      );
    },
  );
}
