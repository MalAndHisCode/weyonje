import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../ui/weyonje_button.dart';
import '../application/client_location_gateway.dart';
import '../application/workflow_providers.dart';
import 'weyonje_map.dart';

/// A route-sized map with no scrolling ancestor. Only explicit input selects.
class RequestLocationPickerScreen extends ConsumerStatefulWidget {
  const RequestLocationPickerScreen({this.initialPoint, super.key});
  final Object? initialPoint;

  @override
  ConsumerState<RequestLocationPickerScreen> createState() => _PickerState();
}

class _PickerState extends ConsumerState<RequestLocationPickerScreen>
    with WidgetsBindingObserver {
  bool _closed = false;
  bool _checking = true;
  bool _ready = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    _closed = true;
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final generation = ++_generation;
    setState(() => _checking = true);
    var ready = false;
    try {
      ready =
          await ref.read(clientLocationGatewayProvider).check() ==
          ClientLocationAccess.ready;
    } catch (_) {
      // A failed availability check never invents a successful selection.
    }
    if (!mounted || _closed || generation != _generation) return;
    setState(() {
      _ready = ready;
      _checking = false;
    });
  }

  void _select(LatLng point) {
    if (!mounted ||
        _closed ||
        _checking ||
        !_ready ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _closed = true;
    context.pop({'latitude': point.latitude, 'longitude': point.longitude});
  }

  Future<void> _coordinates() async {
    final point = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CoordinateEntry(),
    );
    if (point != null && mounted && !_closed) _select(point);
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.initialPoint is LatLng
        ? widget.initialPoint as LatLng
        : const LatLng(0.3476, 32.5825);
    final configured = ref.watch(mapSelectionProvider).configured;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _closed = true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (configured && _ready && !_checking)
                ref.watch(requestMapBuilderProvider)(
                  WeyonjeMap(
                    destinationLatitude: point.latitude,
                    destinationLongitude: point.longitude,
                    hasDestination: widget.initialPoint is LatLng,
                    height: null,
                    onSelected: _select,
                  ),
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _checking
                          ? 'Checking location access…'
                          : !configured
                          ? 'Google Map is unavailable in this build. Close to return to your request.'
                          : 'Location access is required. Close and use Location Settings on your request.',
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close Map',
                        onPressed: () {
                          _closed = true;
                          context.pop();
                        },
                        icon: const Icon(Icons.close),
                      ),
                      const Expanded(
                        child: Text('Tap a location to select it'),
                      ),
                      IconButton(
                        tooltip: 'Enter Coordinates',
                        onPressed: _ready && !_checking && configured
                            ? _coordinates
                            : null,
                        icon: const Icon(Icons.edit_location_alt_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An explicit coordinate entry alternative for users unable to tap the map.
/// Submitting the numeric input returns directly, with no pin-confirmation step.
class _CoordinateEntry extends StatefulWidget {
  const _CoordinateEntry();
  @override
  State<_CoordinateEntry> createState() => _CoordinateEntryState();
}

class _CoordinateEntryState extends State<_CoordinateEntry> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _submit() {
    final lat = double.tryParse(_latitude.text.trim());
    final lng = double.tryParse(_longitude.text.trim());
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      setState(() => _error = 'Enter valid latitude and longitude values.');
      return;
    }
    Navigator.pop(context, LatLng(lat, lng));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FTextField(
            control: FTextFieldControl.managed(controller: _latitude),
            label: const Text('Latitude'),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          ),
          const SizedBox(height: 12),
          FTextField(
            control: FTextFieldControl.managed(controller: _longitude),
            label: const Text('Longitude'),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            textInputAction: TextInputAction.done,
            onSubmit: (_) => _submit(),
          ),
          if (_error != null) Text(_error!),
          const SizedBox(height: 16),
          WeyonjeButton(label: 'Use Entered Coordinates', onPressed: _submit),
        ],
      ),
    ),
  );
}
