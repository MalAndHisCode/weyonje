import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';

class RegistrationUnavailableScreen extends StatelessWidget {
  const RegistrationUnavailableScreen({required this.accountLabel, super.key});

  final String accountLabel;

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: '$accountLabel registration',
    showBack: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeyonjeAlert(
          title: 'Registration is not available',
          message:
              '$accountLabel registration is outside this application version. No account information has been collected.',
        ),
        const SizedBox(height: 24),
        WeyonjeButton(
          label: 'Sign in to an existing account',
          kind: WeyonjeButtonKind.secondary,
          onPressed: () => context.go('/sign-in'),
        ),
        const SizedBox(height: 12),
        WeyonjeButton(
          label: 'Return to account types',
          kind: WeyonjeButtonKind.outline,
          onPressed: () => context.go('/account-type'),
        ),
      ],
    ),
  );
}
