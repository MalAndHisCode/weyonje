import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_actor.dart';
import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/launch_controller.dart';

class ProviderAccountStatusScreen extends ConsumerWidget {
  const ProviderAccountStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(launchControllerProvider);
    final status = state is LaunchAuthenticated
        ? state.actor.providerStatus
        : null;
    final (title, message) = switch (status) {
      ProviderStatus.pending => (
        'Approval pending',
        'KCCA has not yet approved this Service Provider account. Provider work is unavailable.',
      ),
      ProviderStatus.rejected => (
        'Account rejected',
        'KCCA did not approve this Service Provider account. Provider work is unavailable.',
      ),
      ProviderStatus.inactive => (
        'Account inactive',
        'This Service Provider account is inactive. Provider work is unavailable.',
      ),
      ProviderStatus.disabled => (
        'Account disabled',
        'This Service Provider account is disabled. Provider work is unavailable.',
      ),
      _ => (
        'Provider access restricted',
        'This Service Provider account is not eligible for provider work.',
      ),
    };
    return WeyonjePage(
      title: 'Account status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeyonjeAlert(title: title, message: message),
          const SizedBox(height: 24),
          WeyonjeButton(
            label: 'Sign out',
            onPressed: () =>
                ref.read(launchControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}
