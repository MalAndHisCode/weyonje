import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class WeyonjeAlert extends StatelessWidget {
  const WeyonjeAlert({
    required this.title,
    required this.message,
    this.error = false,
    super.key,
  });

  final String title;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => FAlert(
    variant: error ? FAlertVariant.destructive : FAlertVariant.primary,
    title: Text(title),
    subtitle: Text(message),
  );
}
