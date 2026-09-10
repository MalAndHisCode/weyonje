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
    final actor = state is LaunchAuthenticated ? state.actor : null;
    final (title, message) = switch (status) {
      ProviderStatus.pending => (
        'Approval Pending',
        'KCCA has not yet approved this Service Provider account. Provider work is unavailable.',
      ),
      ProviderStatus.rejected => (
        'Account Rejected',
        actor?.providerRejectionReason == null
            ? 'KCCA did not approve this Service Provider account. Provider work is unavailable.'
            : 'KCCA did not approve this Service Provider account. Reason: ${actor!.providerRejectionReason}',
      ),
      ProviderStatus.inactive => (
        'Account Inactive',
        'This Service Provider account is inactive. Provider work is unavailable.',
      ),
      ProviderStatus.disabled => (
        'Account Disabled',
        'This Service Provider account is disabled. Provider work is unavailable.',
      ),
      _ => (
        'Provider Access Restricted',
        'This Service Provider account is not eligible for provider work.',
      ),
    };
    return WeyonjePage(
      title: 'Account Status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeyonjeAlert(title: title, message: message),
          if (actor?.providerNumber != null) ...[
            const SizedBox(height: 16),
            Semantics(
              label: 'Service Provider number ${actor!.providerNumber}',
              child: Text('Provider number: ${actor.providerNumber}'),
            ),
          ],
          const SizedBox(height: 24),
          WeyonjeButton(
            label: 'Sign Out',
            onPressed: () =>
                ref.read(launchControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}
