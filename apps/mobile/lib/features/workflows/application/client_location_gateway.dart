import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/workflow_repository.dart';
import 'workflow_providers.dart';

enum ClientLocationAccess { ready, servicesDisabled, denied, deniedForever }

final clientLocationGatewayProvider = Provider<ClientLocationGateway>(
  (ref) => ClientLocationGateway(ref),
);

/// Foreground checks only. Request entry never starts journey tracking.
class ClientLocationGateway {
  ClientLocationGateway(this.ref);
  final Ref ref;

  Future<ClientLocationAccess> check({bool requestPermission = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return ClientLocationAccess.servicesDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => ClientLocationAccess.ready,
      LocationPermission.deniedForever => ClientLocationAccess.deniedForever,
      _ => ClientLocationAccess.denied,
    };
  }

  Future<DevicePoint> current() => ref
      .read(deviceLocationProvider)
      .current()
      .timeout(const Duration(seconds: 20));

  Future<void> settings(ClientLocationAccess? access) async {
    if (access == ClientLocationAccess.servicesDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
