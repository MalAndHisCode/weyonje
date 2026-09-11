import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

class WeyonjePage extends StatelessWidget {
  const WeyonjePage({
    required this.child,
    this.title,
    this.titleStyle,
    this.showBack = false,
    this.centerVertically = false,
    super.key,
  });

  final Widget child;
  final String? title;
  final TextStyle? titleStyle;
  final bool showBack;
  final bool centerVertically;

  @override
  Widget build(BuildContext context) => FScaffold(
    childPad: false,
    header: title == null
        ? null
        : FHeader.nested(
            title: Text(
              title!,
              style: titleStyle,
              maxLines: 4,
              softWrap: true,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
            prefixes: [
              if (showBack)
                FHeaderAction.back(
                  semanticsLabel: 'Back',
                  onPress: () =>
                      context.canPop() ? context.pop() : context.go('/welcome'),
                ),
            ],
          ),
    child: SafeArea(
      top: title == null,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480,
                minHeight: centerVertically
                    ? (constraints.maxHeight - 44).clamp(0, double.infinity)
                    : 0,
              ),
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: centerVertically ? Center(child: child) : child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
