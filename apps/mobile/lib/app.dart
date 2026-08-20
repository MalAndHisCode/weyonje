import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import 'features/auth/application/launch_controller.dart';
import 'navigation/app_router.dart';
import 'theme/theme.dart';
import 'core/notifications/push_notification_coordinator.dart';
import 'features/workflows/application/journey_tracking_coordinator.dart';

class WeyonjeApplication extends ConsumerStatefulWidget {
  const WeyonjeApplication({super.key});

  @override
  ConsumerState<WeyonjeApplication> createState() => _WeyonjeApplicationState();
}

class _WeyonjeApplicationState extends ConsumerState<WeyonjeApplication>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _pushRoutes;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(
      () => ref.read(launchControllerProvider.notifier).initialize(),
    );
    ref.listenManual<LaunchState>(launchControllerProvider, (_, next) {
      if (next is LaunchAuthenticated) {
        final push = ref.read(pushNotificationCoordinatorProvider);
        push.start();
        _pushRoutes ??= push.routes.listen(
          (route) => ref.read(appRouterProvider).go(route),
        );
        ref.read(journeyTrackingCoordinatorProvider).restore();
      } else if (next is LaunchUnauthenticated || next is LaunchAccessDenied) {
        ref.read(pushNotificationCoordinatorProvider).disable();
        ref.read(journeyTrackingCoordinatorProvider).clear();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushRoutes?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(launchControllerProvider.notifier).revalidateOnResume();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ref.read(launchControllerProvider.notifier).cancelActiveCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Weyonje',
      debugShowCheckedModeBanner: false,
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      theme: lightTheme.toApproximateMaterialTheme(),
      darkTheme: lightTheme.toApproximateMaterialTheme(),
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) => FTheme(
        data: lightTheme,
        child: FToaster(
          child: FTooltipGroup(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
