import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/launch_controller.dart';

class AccessDeniedScreen extends ConsumerWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(launchControllerProvider);
    final message = state is LaunchAccessDenied
        ? state.message
        : 'This account is not permitted to use Weyonje mobile services.';
    return WeyonjePage(
      centerVertically: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeyonjeAlert(title: 'Access Denied', message: message, error: true),
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
