import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/launch_controller.dart';

class SessionErrorScreen extends ConsumerWidget {
  const SessionErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(launchControllerProvider);
    final error = state is LaunchTransientError
        ? state
        : const LaunchTransientError(
            'Weyonje could not verify your session. Retry in a moment.',
          );
    return WeyonjePage(
      centerVertically: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeyonjeAlert(
            title: 'Session check failed',
            message: error.message,
            error: true,
          ),
          const SizedBox(height: 24),
          WeyonjeButton(
            key: const Key('retry-session'),
            label: 'Retry session check',
            loading: error.retryInProgress,
            onPressed: () =>
                ref.read(launchControllerProvider.notifier).retry(),
          ),
        ],
      ),
    );
  }
}
