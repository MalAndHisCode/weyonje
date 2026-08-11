import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/sign_in_controller.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signInControllerProvider);
    return WeyonjePage(
      title: 'Sign in',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Continue securely in your browser to sign in to Weyonje.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Weyonje does not collect your password on this screen. After sign-in, your account role and access are checked before protected content is opened.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (state.message case final message?) ...[
            const SizedBox(height: 24),
            WeyonjeAlert(
              title: 'Sign-in not completed',
              message: message,
              error: true,
            ),
          ],
          const SizedBox(height: 32),
          WeyonjeButton(
            key: const Key('continue-sign-in'),
            label: 'Continue to sign in',
            loading: state.inProgress,
            autofocus: true,
            onPressed: () =>
                ref.read(signInControllerProvider.notifier).signIn(),
          ),
        ],
      ),
    );
  }
}
