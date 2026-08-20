import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_page.dart';
import '../application/workflow_providers.dart';
import '../application/journey_tracking_coordinator.dart';
import '../data/workflow_repository.dart';
import '../domain/workflow_models.dart';
import 'workflow_widgets.dart';
import 'weyonje_map.dart';

class JourneyTrackingScreen extends ConsumerStatefulWidget {
  const JourneyTrackingScreen({
    required this.requestId,
    required this.phase,
    this.providerMode = false,
    super.key,
  });
  final String requestId;
  final String phase;
  final bool providerMode;
  @override
  ConsumerState<JourneyTrackingScreen> createState() =>
      _JourneyTrackingScreenState();
}

class _JourneyTrackingScreenState extends ConsumerState<JourneyTrackingScreen> {
  JourneySnapshot? _snapshot;
  LocationPolicy? _policy;
  MapRouteGuidance? _route;
  Object? _error;
  bool _loading = true;
  JourneyRealtimeClient? _realtime;
  StreamSubscription<void>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final repository = ref.read(workflowRepositoryProvider);
      final values = await Future.wait<Object>([
        repository.tracking(widget.requestId, widget.phase),
        repository.locationPolicy(),
      ]);
      if (!mounted) return;
      _snapshot = values[0] as JourneySnapshot;
      _policy = values[1] as LocationPolicy;
      setState(() => _loading = false);
      await _loadRoute();
      final realtime = JourneyRealtimeClient(
        ref.read(appConfigProvider),
        repository,
      );
      _realtime = realtime;
      _realtimeSubscription = (await realtime.connect(
        widget.requestId,
        widget.phase,
      )).listen((_) => _reconcile());
      if (widget.providerMode && _snapshot!.status == 'ACTIVE') {
        await ref
            .read(journeyTrackingCoordinatorProvider)
            .start(widget.requestId, widget.phase, _policy!);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _reconcile() async {
    try {
      final value = await ref
          .read(workflowRepositoryProvider)
          .tracking(widget.requestId, widget.phase);
      if (mounted) {
        setState(() {
          _snapshot = value;
          _error = null;
        });
      }
      await _loadRoute();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _loadRoute() async {
    final value = _snapshot;
    if (!ref.read(mapSelectionProvider).configured ||
        value?.latitude == null ||
        value?.longitude == null) {
      return;
    }
    try {
      final route = await ref
          .read(workflowRepositoryProvider)
          .routeGuidance(
            value!.latitude!,
            value.longitude!,
            value.destinationLatitude,
            value.destinationLongitude,
          );
      if (mounted) setState(() => _route = route);
    } catch (_) {
      // Persisted coordinates and status remain available without route guidance.
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _realtime?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: widget.phase == 'TO_REQUEST'
        ? 'Journey to request'
        : 'Journey to disposal site',
    showBack: true,
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _snapshot == null
        ? WorkflowErrorView(
            error:
                _error ?? const WorkflowException('Tracking is unavailable.'),
            onRetry: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _initialize();
            },
          )
        : _content(context, _snapshot!),
  );

  Widget _content(BuildContext context, JourneySnapshot value) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_error != null) ...[
        WorkflowErrorView(error: _error!, onRetry: _reconcile),
        const SizedBox(height: 12),
      ],
      if (!ref.watch(mapSelectionProvider).configured)
        const WeyonjeAlert(
          title: 'Live map unavailable',
          message:
              'The authorised Google Maps project is not configured. Weyonje shows authenticated, persisted coordinates and status without fabricating a map.',
        ),
      if (ref.watch(mapSelectionProvider).configured)
        WeyonjeMap(
          destinationLatitude: value.destinationLatitude,
          destinationLongitude: value.destinationLongitude,
          providerLatitude: value.latitude,
          providerLongitude: value.longitude,
          encodedRoute: _route?.encodedPolyline,
        ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: ${humanStatus(value.status)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Destination: ${value.destinationLatitude.toStringAsFixed(5)}, ${value.destinationLongitude.toStringAsFixed(5)}',
              ),
              if (value.latitude != null)
                Text(
                  'Latest Provider position: ${value.latitude!.toStringAsFixed(5)}, ${value.longitude!.toStringAsFixed(5)}',
                ),
              if (value.accuracyMetres != null)
                Text('Accuracy: ${value.accuracyMetres!.round()} metres'),
              if (_route != null)
                Text(
                  'Google route guidance: ${(_route!.distanceMetres / 1000).toStringAsFixed(1)} km, estimated ${_route!.duration}.',
                ),
              Text(
                value.stale
                    ? 'Location is stale; reconciling with the server.'
                    : 'Location is current.',
              ),
              Text('${value.positionCount} accepted position samples'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(_policy?.approvalNotice ?? 'Location policy unavailable.'),
      if (widget.providerMode) ...[
        const SizedBox(height: 8),
        Text(
          _policy?.backgroundTrackingEnabled == true
              ? 'Tracking uses the provisional foreground/background boundary for this active journey. Stop by completing the journey, signing out, or leaving the authorised workflow.'
              : 'Background tracking is disabled by policy.',
        ),
      ],
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: _reconcile,
        child: const Text('Refresh from server'),
      ),
    ],
  );
}
