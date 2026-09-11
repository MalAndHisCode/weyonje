import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_logo.dart';
import '../../../ui/weyonje_page.dart';
import '../application/launch_controller.dart';
import '../../../navigation/app_router.dart';

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
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 24),
            WeyonjeAlert(title: 'Session Ended', message: message),
          ],
          const SizedBox(height: 32),
          WeyonjeButton(
            key: const Key('create-account'),
            label: 'Create Account',
            onPressed: () => context.push('/account-type'),
          ),
          const SizedBox(height: 12),
          WeyonjeButton(
            key: const Key('sign-in'),
            label: 'Client Sign In',
            kind: WeyonjeButtonKind.secondary,
            onPressed: () => context.push('/sign-in/client'),
          ),
          const SizedBox(height: 12),
          WeyonjeButton(
            key: const Key('staff-sign-in'),
            label: 'Service Provider Sign In',
            kind: WeyonjeButtonKind.secondary,
            onPressed: () => context.push(AppRoutes.providerSignIn),
          ),
          const SizedBox(height: 12),
          WeyonjeButton(
            key: const Key('kcca-sign-in'),
            label: 'KCCA Sign In',
            kind: WeyonjeButtonKind.secondary,
            onPressed: () => context.push(AppRoutes.kccaSignIn),
          ),
        ],
      ),
    );
  }
}
