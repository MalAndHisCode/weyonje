import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_logo.dart';
import '../../../ui/weyonje_page.dart';
import '../application/launch_controller.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(launchControllerProvider);
    final message = state is LaunchUnauthenticated ? state.message : null;
    return WeyonjePage(
      centerVertically: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WeyonjeLogo(),
          Semantics(
            header: true,
            child: Text(
              'Welcome to Weyonje',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create an account to request or provide waste-collection services.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (message != null) ...[
            const SizedBox(height: 24),
            WeyonjeAlert(title: 'Session ended', message: message),
          ],
          const SizedBox(height: 32),
          WeyonjeButton(
            key: const Key('create-account'),
            label: 'Create account',
            onPressed: () => context.push('/account-type'),
          ),
          const SizedBox(height: 12),
          WeyonjeButton(
            key: const Key('sign-in'),
            label: 'Client sign in',
            kind: WeyonjeButtonKind.secondary,
            onPressed: () => context.push('/sign-in/client'),
          ),
          const SizedBox(height: 12),
          WeyonjeButton(
            key: const Key('staff-sign-in'),
            label: 'Provider or KCCA sign in',
            kind: WeyonjeButtonKind.outline,
            onPressed: () => context.push('/sign-in'),
          ),
        ],
      ),
    );
  }
}
