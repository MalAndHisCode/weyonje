import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class WeyonjeDialog extends StatelessWidget {
  const WeyonjeDialog({
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => FDialog(
    builder: (context, style) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: DefaultTextStyle(
              style: context.theme.typography.display.lg,
              child: title,
            ),
          ),
          const SizedBox(height: 16),
          content,
          const SizedBox(height: 24),
          for (final action in actions)
            Padding(padding: const EdgeInsets.only(top: 8), child: action),
        ],
      ),
    ),
  );
}
