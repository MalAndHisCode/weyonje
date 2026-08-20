import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../data/workflow_repository.dart';

final workflowRepositoryProvider = Provider<WorkflowRepository>(
  (ref) => NativeWorkflowRepository(
    ref.watch(appConfigProvider),
    ref.watch(sessionStoreProvider),
    ref.watch(dioProvider),
  ),
);

final deviceLocationProvider = Provider<DeviceLocationGateway>(
  (ref) => PlatformDeviceLocationGateway(),
);

final mapSelectionProvider = Provider<MapSelectionGateway>(
  (ref) => ref.watch(appConfigProvider).googleMapsEnabled
      ? const ConfiguredGoogleMapsGateway()
      : const UnconfiguredGoogleMapsGateway(),
);
