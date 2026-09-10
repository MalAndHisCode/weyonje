import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/launch_controller.dart';

class AuthorizedDestinationUnavailableScreen extends ConsumerWidget {
  const AuthorizedDestinationUnavailableScreen({
    required this.destinationName,
    super.key,
  });

  final String destinationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) => WeyonjePage(
    title: destinationName,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeyonjeAlert(
          title: '$destinationName Unavailable',
          message:
              'Your session and access were verified, but $destinationName functionality is outside this application version. No protected work data has been loaded.',
        ),
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
