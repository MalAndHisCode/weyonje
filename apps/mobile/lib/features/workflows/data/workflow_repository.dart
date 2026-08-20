import 'dart:async';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/config/app_config.dart';
import '../domain/workflow_models.dart';

abstract interface class WorkflowRepository {
  Future<WorkflowDashboard> clientDashboard();
  Future<WorkflowDashboard> providerDashboard();
  Future<List<ServiceRequestSummary>> clientRequests();
  Future<ServiceRequestDetail> clientRequest(String id);
  Future<ServiceRequestDetail> createClientRequest(Map<String, Object?> data);
  Future<List<ProviderPendingRequest>> pendingProviderRequests();
  Future<ServiceRequestDetail> providerRequest(String id);
  Future<ServiceRequestDetail> acceptRequest(String id, {int? agreedPriceUgx});
  Future<void> rejectRequest(String id);
  Future<List<ServiceRequestSummary>> providerJobs();
  Future<ServiceRequestDetail> providerJob(String id);
  Future<ServiceRequestDetail> startJourney(String id, String phase);
  Future<JourneySnapshot> submitPosition(
    String id,
    String phase,
    DevicePoint point,
  );
  Future<ServiceRequestDetail> reportCollection(String id);
  Future<ServiceRequestDetail> submitFeedback(
    String id, {
    required String outcome,
    required String feedback,
    required int rating,
  });
  Future<ServiceRequestDetail> completeDisposal(String id);
  Future<JourneySnapshot> tracking(String id, String phase);
  Future<List<ServiceRequestSummary>> kccaMonitoring();
  Future<List<OperationalNotification>> notifications();
  Future<void> markNotificationRead(String id);
  Future<LocationPolicy> locationPolicy();
  Future<List<ProviderAdministration>> providers(String status);
  Future<ProviderAdministration> decideProvider(
    String id,
    String decision, {
    String? reason,
  });
  Future<ProviderAdministration> changeProviderStatus(
    String id,
    String status, {
    String? reason,
  });
  Future<List<ServiceRequestSummary>> callCentreRequests();
  Future<List<CallCentreClient>> callCentreClients(String query);
  Future<List<EligibleProvider>> callCentreProviders();
  Future<ServiceRequestDetail> createCallCentreRequest(
    Map<String, Object?> data,
  );
  Future<ServiceRequestDetail> assignCallCentreRequest(
    String id,
    String providerId, {
    int? priceUgx,
  });
  Future<List<DisposalSite>> disposalSites();
  Future<DisposalSite> saveDisposalSite(Map<String, Object?> data);
  Future<List<MapPlace>> searchPlaces(String text);
  Future<String?> reverseGeocode(double latitude, double longitude);
  Future<MapRouteGuidance?> routeGuidance(
    double originLatitude,
    double originLongitude,
    double destinationLatitude,
    double destinationLongitude,
  );
  Future<String> accessToken();
}

class NativeWorkflowRepository implements WorkflowRepository {
  NativeWorkflowRepository(this._config, this._sessions, this._dio);

  final AppConfig _config;
  final SessionStore _sessions;
  final Dio _dio;
  static const _uuid = Uuid();

  Future<Options> _options() async =>
      Options(headers: {'Authorization': 'Bearer ${await accessToken()}'});

  @override
  Future<String> accessToken() async {
    final configurationError = _config.validate();
    if (configurationError != null) {
      throw WorkflowException(configurationError);
    }
    final session = await _sessions.read();
    if (session == null) {
      throw const WorkflowException(
        'Your session is unavailable. Sign in again.',
      );
    }
    return session.accessToken;
  }

  Future<Object?> _get(String path) async {
    try {
      return (await _dio.get<Object?>(path, options: await _options())).data;
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Future<Object?> _send(
    String method,
    String path,
    Map<String, Object?> data,
  ) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        options: (await _options()).copyWith(method: method),
      );
      return response.data;
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  WorkflowException _failure(DioException error) {
    final body = error.response?.data;
    if (body is Map) {
      final message = body['message'];
      final code = body['code'];
      if (message is String) {
        return WorkflowException(message, code: code is String ? code : null);
      }
    }
    if (error.response?.statusCode == 401) {
      return const WorkflowException(
        'Your session expired. Sign in again.',
        code: 'AUTHENTICATION_REQUIRED',
      );
    }
    return const WorkflowException(
      'Weyonje could not load this work. Check your connection and retry.',
    );
  }

  @override
  Future<WorkflowDashboard> clientDashboard() async =>
      WorkflowDashboard.fromJson(await _get('/v1/client/dashboard'));
  @override
  Future<WorkflowDashboard> providerDashboard() async =>
      WorkflowDashboard.fromJson(await _get('/v1/provider/dashboard'));
  @override
  Future<List<ServiceRequestSummary>> clientRequests() async => jsonList(
    await _get('/v1/client/requests'),
  ).map(ServiceRequestSummary.fromJson).toList(growable: false);
  @override
  Future<ServiceRequestDetail> clientRequest(String id) async =>
      ServiceRequestDetail.fromJson(await _get('/v1/client/requests/$id'));
  @override
  Future<ServiceRequestDetail> createClientRequest(
    Map<String, Object?> data,
  ) async => ServiceRequestDetail.fromJson(
    await _send('POST', '/v1/client/requests', {
      ...data,
      'idempotencyKey': _uuid.v4(),
    }),
  );
  @override
  Future<List<ProviderPendingRequest>> pendingProviderRequests() async =>
      jsonList(
        await _get('/v1/provider/requests/pending'),
      ).map(ProviderPendingRequest.fromJson).toList(growable: false);
  @override
  Future<ServiceRequestDetail> providerRequest(String id) async =>
      ServiceRequestDetail.fromJson(await _get('/v1/provider/requests/$id'));
  @override
  Future<ServiceRequestDetail> acceptRequest(
    String id, {
    int? agreedPriceUgx,
  }) async => ServiceRequestDetail.fromJson(
    await _send('POST', '/v1/provider/requests/$id/accept', {
      'idempotencyKey': _uuid.v4(),
      'agreedPriceUgx': ?agreedPriceUgx,
    }),
  );
  @override
  Future<void> rejectRequest(String id) async => _send(
    'POST',
    '/v1/provider/requests/$id/reject',
    {'idempotencyKey': _uuid.v4()},
  );
  @override
  Future<List<ServiceRequestSummary>> providerJobs() async => jsonList(
    await _get('/v1/provider/jobs'),
  ).map(ServiceRequestSummary.fromJson).toList(growable: false);
  @override
  Future<ServiceRequestDetail> providerJob(String id) async =>
      ServiceRequestDetail.fromJson(await _get('/v1/provider/jobs/$id'));
  @override
  Future<ServiceRequestDetail> startJourney(String id, String phase) async =>
      ServiceRequestDetail.fromJson(
        await _send('POST', '/v1/provider/jobs/$id/journeys/$phase/start', {
          'idempotencyKey': _uuid.v4(),
        }),
      );
  @override
  Future<JourneySnapshot> submitPosition(
    String id,
    String phase,
    DevicePoint point,
  ) async => JourneySnapshot.fromJson(
    await _send('POST', '/v1/provider/jobs/$id/positions', {
      'phase': phase,
      'samples': [
        {
          'sampleId': point.sampleId,
          'deviceTimestamp': point.timestamp.toUtc().toIso8601String(),
          'latitude': point.latitude,
          'longitude': point.longitude,
          'accuracyMetres': point.accuracyMetres,
        },
      ],
    }),
  );
  @override
  Future<ServiceRequestDetail> reportCollection(String id) async =>
      ServiceRequestDetail.fromJson(
        await _send('POST', '/v1/provider/jobs/$id/collection-completed', {
          'idempotencyKey': _uuid.v4(),
        }),
      );
  @override
  Future<ServiceRequestDetail> submitFeedback(
    String id, {
    required String outcome,
    required String feedback,
    required int rating,
  }) async => ServiceRequestDetail.fromJson(
    await _send('POST', '/v1/client/requests/$id/feedback', {
      'idempotencyKey': _uuid.v4(),
      'outcome': outcome,
      'feedback': feedback,
      'rating': rating,
    }),
  );
  @override
  Future<ServiceRequestDetail> completeDisposal(String id) async =>
      ServiceRequestDetail.fromJson(
        await _send('POST', '/v1/provider/jobs/$id/disposal-completed', {
          'idempotencyKey': _uuid.v4(),
        }),
      );
  @override
  Future<JourneySnapshot> tracking(String id, String phase) async =>
      JourneySnapshot.fromJson(await _get('/v1/journeys/$id?phase=$phase'));
  @override
  Future<List<ServiceRequestSummary>> kccaMonitoring() async => jsonList(
    await _get('/v1/kcca/monitoring'),
  ).map(ServiceRequestSummary.fromJson).toList(growable: false);
  @override
  Future<List<OperationalNotification>> notifications() async => jsonList(
    await _get('/v1/notifications'),
  ).map(OperationalNotification.fromJson).toList(growable: false);
  @override
  Future<void> markNotificationRead(String id) async =>
      _send('POST', '/v1/notifications/$id/read', const {});
  @override
  Future<LocationPolicy> locationPolicy() async {
    try {
      return LocationPolicy.fromJson(
        (await _dio.get<Object?>('/v1/config/location-policy')).data,
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<List<ProviderAdministration>> providers(String status) async =>
      jsonList(
        await _get('/v1/provider-registrations?status=$status'),
      ).map(ProviderAdministration.fromJson).toList(growable: false);

  @override
  Future<ProviderAdministration> decideProvider(
    String id,
    String decision, {
    String? reason,
  }) async {
    await _send('POST', '/v1/provider-registrations/$id/decision', {
      'decision': decision,
      'reason': ?reason,
    });
    return ProviderAdministration.fromJson(
      await _get('/v1/provider-registrations/$id'),
    );
  }

  @override
  Future<ProviderAdministration> changeProviderStatus(
    String id,
    String status, {
    String? reason,
  }) async => ProviderAdministration.fromJson(
    await _send('POST', '/v1/provider-registrations/$id/status', {
      'status': status,
      'reason': ?reason,
    }),
  );

  @override
  Future<List<ServiceRequestSummary>> callCentreRequests() async => jsonList(
    await _get('/v1/call-centre/requests'),
  ).map(ServiceRequestSummary.fromJson).toList(growable: false);

  @override
  Future<List<CallCentreClient>> callCentreClients(String query) async =>
      jsonList(
        await _get(
          '/v1/call-centre/clients?query=${Uri.encodeQueryComponent(query)}',
        ),
      ).map(CallCentreClient.fromJson).toList(growable: false);

  @override
  Future<List<EligibleProvider>> callCentreProviders() async => jsonList(
    await _get('/v1/call-centre/providers'),
  ).map(EligibleProvider.fromJson).toList(growable: false);

  @override
  Future<ServiceRequestDetail> createCallCentreRequest(
    Map<String, Object?> data,
  ) async => ServiceRequestDetail.fromJson(
    await _send('POST', '/v1/call-centre/requests', {
      ...data,
      'idempotencyKey': _uuid.v4(),
    }),
  );

  @override
  Future<ServiceRequestDetail> assignCallCentreRequest(
    String id,
    String providerId, {
    int? priceUgx,
  }) async => ServiceRequestDetail.fromJson(
    await _send('POST', '/v1/call-centre/requests/$id/assignment', {
      'idempotencyKey': _uuid.v4(),
      'providerUserId': providerId,
      'agreedPriceUgx': ?priceUgx,
    }),
  );

  @override
  Future<List<DisposalSite>> disposalSites() async => jsonList(
    await _get('/v1/kcca/disposal-sites'),
  ).map(DisposalSite.fromJson).toList(growable: false);

  @override
  Future<DisposalSite> saveDisposalSite(Map<String, Object?> data) async =>
      DisposalSite.fromJson(
        await _send('PUT', '/v1/kcca/disposal-sites', data),
      );

  @override
  Future<List<MapPlace>> searchPlaces(String text) async => jsonList(
    await _send('POST', '/v1/maps/search', {'text': text}),
  ).map(MapPlace.fromJson).toList(growable: false);

  @override
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    final value = jsonObject(
      await _get('/v1/maps/reverse?latitude=$latitude&longitude=$longitude'),
    );
    return value['address'] as String?;
  }

  @override
  Future<MapRouteGuidance?> routeGuidance(
    double originLatitude,
    double originLongitude,
    double destinationLatitude,
    double destinationLongitude,
  ) async {
    final value = await _send('POST', '/v1/maps/route', {
      'origin': {'latitude': originLatitude, 'longitude': originLongitude},
      'destination': {
        'latitude': destinationLatitude,
        'longitude': destinationLongitude,
      },
    });
    return value == null ? null : MapRouteGuidance.fromJson(value);
  }
}

class DevicePoint {
  const DevicePoint({
    required this.sampleId,
    required this.latitude,
    required this.longitude,
    required this.accuracyMetres,
    required this.timestamp,
  });
  final String sampleId;
  final double latitude;
  final double longitude;
  final double accuracyMetres;
  final DateTime timestamp;
}

abstract interface class DeviceLocationGateway {
  Future<DevicePoint> current();
  Stream<DevicePoint> watch(LocationPolicy policy);
}

class PlatformDeviceLocationGateway implements DeviceLocationGateway {
  Future<LocationPermission> _permission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const WorkflowException(
        'Turn on device location services and try again.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const WorkflowException(
        'Location permission is required for this action.',
      );
    }
    return permission;
  }

  @override
  Future<DevicePoint> current() async {
    await _permission();
    return _point(
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ),
    );
  }

  @override
  Stream<DevicePoint> watch(LocationPolicy policy) async* {
    await _permission();
    yield* Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: policy.sampleDistanceMetres.round(),
      ),
    ).map(_point);
  }

  DevicePoint _point(Position position) => DevicePoint(
    sampleId: const Uuid().v4(),
    latitude: position.latitude,
    longitude: position.longitude,
    accuracyMetres: position.accuracy,
    timestamp: position.timestamp,
  );
}

abstract interface class MapSelectionGateway {
  bool get configured;
}

class UnconfiguredGoogleMapsGateway implements MapSelectionGateway {
  const UnconfiguredGoogleMapsGateway();
  @override
  bool get configured => false;
}

class ConfiguredGoogleMapsGateway implements MapSelectionGateway {
  const ConfiguredGoogleMapsGateway();
  @override
  bool get configured => true;
}

class JourneyRealtimeClient {
  JourneyRealtimeClient(this._config, this._repository);
  final AppConfig _config;
  final WorkflowRepository _repository;
  io.Socket? _socket;

  Future<Stream<void>> connect(String requestId, String phase) async {
    final changes = StreamController<void>.broadcast();
    final token = await _repository.accessToken();
    final socket = io.io(
      '${_config.apiBaseUrl}/journeys',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;
    socket.on(
      'connect',
      (_) => socket.emit('journey:reconcile', {
        'requestId': requestId,
        'phase': phase,
      }),
    );
    socket.on('journey:position', (value) {
      final event = value is Map ? value : const {};
      if (event['requestId'] == requestId && event['phase'] == phase) {
        changes.add(null);
      }
    });
    socket.on('disconnect', (_) => changes.add(null));
    socket.connect();
    changes.onCancel = () {
      socket.dispose();
      changes.close();
    };
    return changes.stream;
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
