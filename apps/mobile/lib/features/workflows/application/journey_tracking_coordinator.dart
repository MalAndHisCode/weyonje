import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/workflow_repository.dart';
import '../domain/workflow_models.dart';
import 'workflow_providers.dart';

@pragma('vm:entry-point')
void startJourneyForegroundTask() =>
    FlutterForegroundTask.setTaskHandler(_JourneyTaskHandler());

class _JourneyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class JourneyTrackingCoordinator {
  JourneyTrackingCoordinator(this._repository, this._locations, this._storage);
  final WorkflowRepository _repository;
  final DeviceLocationGateway _locations;
  final FlutterSecureStorage _storage;
  StreamSubscription<DevicePoint>? _movement;
  Timer? _interval;
  String? _requestId;
  String? _phase;
  bool _sending = false;
  static const _activeKey = 'tracking.active.v1';
  static const _queueKey = 'tracking.queue.v1';

  Future<void> restore() async {
    final encoded = await _storage.read(key: _activeKey);
    if (encoded == null || _movement != null) return;
    try {
      final data = (jsonDecode(encoded) as Map).cast<String, dynamic>();
      final id = data['requestId'] as String;
      final phase = data['phase'] as String;
      final snapshot = await _repository.tracking(id, phase);
      if (snapshot.status != 'ACTIVE') return clear();
      await start(id, phase, await _repository.locationPolicy());
    } catch (_) {
      // Retry reconciliation on the next authenticated resume.
    }
  }

  Future<void> start(
    String requestId,
    String phase,
    LocationPolicy policy,
  ) async {
    if (_requestId == requestId && _phase == phase && _movement != null) return;
    await stop(clearStored: false);
    _requestId = requestId;
    _phase = phase;
    await _storage.write(
      key: _activeKey,
      value: jsonEncode({'requestId': requestId, 'phase': phase}),
    );
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'weyonje_active_journey',
        channelName: 'Active Weyonje journey',
        channelDescription:
            'Location sharing for an authorised active Provider journey.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          policy.sampleIntervalSeconds * 1000,
        ),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    await FlutterForegroundTask.startService(
      serviceId: 7321,
      notificationTitle: 'Weyonje journey tracking active',
      notificationText: 'Sharing location for your authorised active job.',
      callback: startJourneyForegroundTask,
    );
    _movement = _locations.watch(policy).listen(_send, onError: (_) {});
    _interval = Timer.periodic(
      Duration(seconds: policy.sampleIntervalSeconds),
      (_) async {
        try {
          await _send(await _locations.current());
        } catch (_) {}
      },
    );
    await _flush();
  }

  Future<void> _send(DevicePoint point) async {
    if (_sending || _requestId == null || _phase == null) {
      if (_requestId != null) await _enqueue(point);
      return;
    }
    _sending = true;
    try {
      await _flush();
      final snapshot = await _repository.submitPosition(
        _requestId!,
        _phase!,
        point,
      );
      if (snapshot.status != 'ACTIVE') await clear();
    } catch (_) {
      await _enqueue(point);
    } finally {
      _sending = false;
    }
  }

  Future<void> _enqueue(DevicePoint point) async {
    final queue = await _readQueue();
    queue.add({
      'sampleId': point.sampleId,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'accuracy': point.accuracyMetres,
      'timestamp': point.timestamp.toUtc().toIso8601String(),
    });
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    queue.removeWhere(
      (item) => DateTime.parse(item['timestamp'] as String).isBefore(cutoff),
    );
    while (queue.length > 200) {
      queue.removeAt(0);
    }
    await _storage.write(key: _queueKey, value: jsonEncode(queue));
  }

  Future<void> _flush() async {
    if (_requestId == null || _phase == null) return;
    final queue = await _readQueue();
    while (queue.isNotEmpty) {
      final item = queue.first;
      await _repository.submitPosition(
        _requestId!,
        _phase!,
        DevicePoint(
          sampleId: item['sampleId'] as String,
          latitude: (item['latitude'] as num).toDouble(),
          longitude: (item['longitude'] as num).toDouble(),
          accuracyMetres: (item['accuracy'] as num).toDouble(),
          timestamp: DateTime.parse(item['timestamp'] as String),
        ),
      );
      queue.removeAt(0);
      await _storage.write(key: _queueKey, value: jsonEncode(queue));
    }
  }

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final encoded = await _storage.read(key: _queueKey);
    if (encoded == null) return [];
    try {
      return (jsonDecode(encoded) as List)
          .map((value) => (value as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clear() => stop(clearStored: true);

  Future<void> stop({bool clearStored = true}) async {
    if (_movement == null && _requestId == null) {
      if (clearStored) {
        try {
          await _storage.delete(key: _activeKey);
          await _storage.delete(key: _queueKey);
        } catch (_) {}
      }
      return;
    }
    await _movement?.cancel();
    _movement = null;
    _interval?.cancel();
    _interval = null;
    _requestId = null;
    _phase = null;
    await FlutterForegroundTask.stopService();
    if (clearStored) {
      try {
        await _storage.delete(key: _activeKey);
        await _storage.delete(key: _queueKey);
      } catch (_) {
        // Plugin storage is unavailable in host-only widget tests.
      }
    }
  }
}

final journeyTrackingCoordinatorProvider = Provider<JourneyTrackingCoordinator>(
  (ref) => JourneyTrackingCoordinator(
    ref.watch(workflowRepositoryProvider),
    ref.watch(deviceLocationProvider),
    const FlutterSecureStorage(aOptions: AndroidOptions()),
  ),
);
