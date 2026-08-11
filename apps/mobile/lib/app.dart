import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import 'features/auth/application/launch_controller.dart';
import 'navigation/app_router.dart';
import 'theme/theme.dart';

class WeyonjeApplication extends ConsumerStatefulWidget {
  const WeyonjeApplication({super.key});

  @override
  ConsumerState<WeyonjeApplication> createState() => _WeyonjeApplicationState();
}

class _WeyonjeApplicationState extends ConsumerState<WeyonjeApplication>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(
      () => ref.read(launchControllerProvider.notifier).initialize(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
