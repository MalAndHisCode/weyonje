import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../../../ui/weyonje_select.dart';
import '../application/client_location_gateway.dart';
import '../application/workflow_providers.dart';
import '../domain/workflow_models.dart';
import 'weyonje_map.dart';

/// Keeps routine form tests independent of the native Maps platform view.
final requestMapBuilderProvider = Provider<Widget Function(WeyonjeMap)>(
  (ref) =>
      (map) => map,
);

class RequestServiceScreen extends ConsumerStatefulWidget {
  const RequestServiceScreen({super.key});
  @override
  ConsumerState<RequestServiceScreen> createState() =>
      _RequestServiceScreenState();
}

class _RequestServiceScreenState extends ConsumerState<RequestServiceScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _address = TextEditingController();
  Map<String, dynamic>? _profile;
  String? _profileError;
  bool? _current;
  LatLng? _point;
  bool _confirmed = false;
  String? _toilet;
  ClientLocationAccess? _access;
  bool _checking = false;
  bool _locating = false;
  bool _geocoding = false;
  bool _addressFromGoogle = false;
  bool _submitting = false;
  bool _submissionUncertain = false;
  bool get _draftLocked => _submitting || _submissionUncertain;
  String? _locationError;
  String? _error;
  String? _phoneError;
  int _selection = 0;
  int _permissionCheck = 0;
  int _profileCheck = 0;
  int _mapRevision = 0;
  String? _payloadSignature;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _contactPhone.addListener(() => _phoneError = null);
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _checkAccess(request: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contactName.dispose();
    _contactPhone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recheck availability without moving an established destination.
      _checkAccess();
    }
  }

  Future<void> _loadProfile() async {
    final generation = ++_profileCheck;
    setState(() {
      _profileError = null;
    });
    try {
      final profile = await ref
          .read(workflowRepositoryProvider)
          .clientProfile();
      if (profile['clientName'] is! String ||
          profile['phoneNumber'] is! String) {
        throw const FormatException('Incomplete client profile.');
      }
      if (mounted && generation == _profileCheck) {
        setState(() => _profile = profile);
      }
    } catch (_) {
      if (mounted && generation == _profileCheck) {
        setState(
          () => _profileError =
              'Client details could not be loaded. Retry to continue.',
        );
      }
    }
  }

  Future<bool> _checkAccess({bool request = false}) async {
    final generation = ++_permissionCheck;
    setState(() => _checking = true);
    try {
      final access = await ref
          .read(clientLocationGatewayProvider)
          .check(requestPermission: request);
      if (!mounted || generation != _permissionCheck) return false;
      setState(() => _access = access);
      return access == ClientLocationAccess.ready;
    } catch (_) {
      if (mounted && generation == _permissionCheck) {
        setState(() {
          _access = null;
          _locationError = 'Location availability could not be checked. Retry.';
        });
      }
      return false;
    } finally {
      if (mounted && generation == _permissionCheck) {
        setState(() => _checking = false);
      }
    }
  }

  void _mode(bool current) {
    if (_draftLocked) return;
    ++_selection;
    setState(() {
      _current = current;
      _point = null;
      _confirmed = false;
      _address.clear();
      _locationError = null;
      _locating = false;
      _geocoding = false;
    });
    if (current) _locate();
  }

  Future<void> _locate() async {
    final generation = ++_selection;
    setState(() {
      _point = null;
      _confirmed = false;
      _address.clear();
      _locating = true;
      _geocoding = false;
      _locationError = null;
    });
    try {
      if (!await _checkAccess(request: true)) return;
      if (!mounted || generation != _selection) return;
      final point = await ref.read(clientLocationGatewayProvider).current();
      if (!mounted || generation != _selection || _current != true) return;
      _select(LatLng(point.latitude, point.longitude), automatic: true);
    } on TimeoutException {
      if (mounted && generation == _selection) {
        setState(
          () => _locationError =
              'Getting your location timed out. Move to an open area and retry.',
        );
      }
    } catch (_) {
      if (mounted && generation == _selection) {
        setState(
          () => _locationError =
              'Your current position is unavailable. Retry when location is available.',
        );
      }
    } finally {
      if (mounted && generation == _selection) {
        setState(() => _locating = false);
      }
    }
  }

  void _select(LatLng point, {bool automatic = false}) {
    if (_draftLocked || (!automatic && _current != false)) return;
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      return;
    }
    final generation = ++_selection;
    setState(() {
      _point = point;
      _confirmed = automatic;
      _address.clear();
      _locationError = null;
      _locating = false;
    });
    _resolveAddress(point, generation);
  }

  Future<void> _chooseLocation() async {
    final generation = _selection;
    final point = await context.push<Map<String, double>>(
      '/client/location-picker',
    );
    if (!mounted ||
        generation != _selection ||
        _current != false ||
        point == null) {
      return;
    }
    _select(LatLng(point['latitude']!, point['longitude']!));
    setState(() => _confirmed = true);
  }

  Future<void> _resolveAddress(LatLng point, int generation) async {
    setState(() {
      _geocoding = true;
      _addressFromGoogle = false;
      _address.clear();
    });
    try {
      final address = await ref
          .read(workflowRepositoryProvider)
          .reverseGeocode(point.latitude, point.longitude);
      if (mounted && generation == _selection) {
        _addressFromGoogle = address?.trim().isNotEmpty == true;
        setState(
          () => _address.text = address?.trim().isNotEmpty == true
              ? address!
              : 'No address returned. Selected coordinates will be used.',
        );
      }
    } catch (_) {
      if (mounted && generation == _selection) {
        setState(
          () => _address.text =
              'Address unavailable. Selected coordinates will be used.',
        );
      }
    } finally {
      if (mounted && generation == _selection) {
        setState(() => _geocoding = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting || !_form.currentState!.validate()) return;
    if (_profile == null || _current == null || _point == null || !_confirmed) {
      setState(
        () => _error =
            'Load Client details, choose Yes or No, and confirm a service location.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (!await _checkAccess(request: true)) return;
      if (!mounted) return;
      final payload = <String, Object?>{
        'locationKind': _current! ? 'CURRENT' : 'MAP_PIN',
        'location': {
          'latitude': _point!.latitude,
          'longitude': _point!.longitude,
        },
        'toiletType': _toilet,
        'scheduleMode': 'ASAP',
        if (_contactName.text.trim().isNotEmpty)
          'additionalContactName': _contactName.text.trim(),
        if (_contactPhone.text.trim().isNotEmpty)
          'additionalContactPhone': _contactPhone.text.trim(),
      };
      final signature = jsonEncode(payload);
      // An unchanged retry replays the server result; an edited request is a new command.
      if (_payloadSignature != signature) {
        _payloadSignature = signature;
        _idempotencyKey = const Uuid().v4();
      }
      final result = await ref
          .read(workflowRepositoryProvider)
          .createClientRequest({...payload, 'idempotencyKey': _idempotencyKey});
      if (mounted) context.go('/client/requests/${result.id}');
    } on WorkflowException catch (error) {
      if (mounted) {
        setState(() {
          _submissionUncertain = error.code == null;
          _error = error.message;
          if (error.message == 'Enter a valid Ugandan phone number.') {
            _phoneError = error.message;
          }
        });
        _form.currentState?.validate();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submissionUncertain = true;
          _error =
              'The response was interrupted. Retry unchanged details to recover the same request.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(mapSelectionProvider).configured;
    final email = _profile?['emailAddress'] as String?;
    return WeyonjePage(
      title: 'Request for a Service',
      showBack: true,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading('Client Details'),
            if (_profileError != null) ...[
              WeyonjeAlert(
                title: 'Client Details Unavailable',
                message: _profileError!,
              ),
              WeyonjeButton(
                label: 'Retry Client Details',
                onPressed: _loadProfile,
              ),
            ] else if (_profile == null)
              const Text('Loading Client details…')
            else ...[
              _detail('Client Name', _profile!['clientName'] as String),
              _detail('Phone Number', _profile!['phoneNumber'] as String),
              if (email?.trim().isNotEmpty == true)
                _detail('Email Address', email!),
            ],
            _heading('Location Details'),
            const Text(
              'Is the Weyonje Service Needed at Your Current Location?',
            ),
            FRadio(
              value: _current == true,
              onChange: _draftLocked ? null : (_) => _mode(true),
              label: const Text('Yes'),
            ),
            FRadio(
              value: _current == false,
              onChange: _draftLocked ? null : (_) => _mode(false),
              label: const Text('No'),
            ),
            if (configured)
              ref.watch(requestMapBuilderProvider)(
                WeyonjeMap(
                  key: ValueKey(_mapRevision),
                  destinationLatitude: _point?.latitude ?? 0.3476,
                  destinationLongitude: _point?.longitude ?? 32.5825,
                  hasDestination: _point != null,
                  showDeviceLocation: _access == ClientLocationAccess.ready,
                  onSelected: _current == false && !_draftLocked
                      ? _select
                      : null,
                ),
              )
            else
              const WeyonjeAlert(
                title: 'Google Map Unavailable',
                message:
                    'Map display is not configured in this build. Current location can still provide coordinates; choosing another location requires a configured map.',
              ),
            FTextField(
              control: FTextFieldControl.managed(controller: _address),
              readOnly: true,
              maxLines: 3,
              label: const Text('Service Location'),
              description: _addressFromGoogle && _address.text.isNotEmpty
                  ? const Text('Google Maps')
                  : null,
              hint: _geocoding
                  ? 'Resolving address…'
                  : 'No service location selected',
            ),
            if (_point != null)
              Text(
                'Coordinates: ${_point!.latitude.toStringAsFixed(6)}, ${_point!.longitude.toStringAsFixed(6)}',
              ),
            if (configured)
              WeyonjeButton(
                label: 'Reload Map',
                kind: WeyonjeButtonKind.outline,
                onPressed: _submitting
                    ? null
                    : () => setState(() => _mapRevision++),
              ),
            if (_current == false) ...[
              const Text('Tap the map, then confirm the selected location.'),
              if (configured)
                WeyonjeButton(
                  label: 'Choose Location in Full Screen',
                  kind: WeyonjeButtonKind.outline,
                  onPressed: _draftLocked ? null : _chooseLocation,
                ),
              WeyonjeButton(
                label: _confirmed ? 'Location Confirmed' : 'Confirm Location',
                kind: WeyonjeButtonKind.outline,
                onPressed: _point == null || _submitting
                    ? null
                    : () => setState(() => _confirmed = true),
              ),
            ],
            if (_current == true)
              WeyonjeButton(
                label: 'Refresh Current Location',
                kind: WeyonjeButtonKind.outline,
                loading: _locating,
                onPressed: _draftLocked || _locating ? null : _locate,
              ),
            if (_point != null && !_geocoding)
              WeyonjeButton(
                label: 'Retry Address',
                kind: WeyonjeButtonKind.outline,
                onPressed: _submitting
                    ? null
                    : () => _resolveAddress(_point!, ++_selection),
              ),
            if (_checking) const Text('Checking location access…'),
            if (_access != ClientLocationAccess.ready && !_checking) ...[
              WeyonjeAlert(
                title: 'Location Access Required',
                message: switch (_access) {
                  ClientLocationAccess.servicesDisabled =>
                    'Device location services are off. Turn them on for either location option.',
                  ClientLocationAccess.deniedForever =>
                    'Location permission is permanently denied. Allow foreground location in app settings.',
                  ClientLocationAccess.denied =>
                    'Location permission was denied. Allow foreground location to submit a request.',
                  _ =>
                    'Location availability has not been confirmed. Retry to continue.',
                },
              ),
              WeyonjeButton(
                label: 'Retry Location Access',
                kind: WeyonjeButtonKind.outline,
                onPressed: () => _checkAccess(request: true),
              ),
              WeyonjeButton(
                label: 'Open Location Settings',
                kind: WeyonjeButtonKind.outline,
                onPressed: () =>
                    ref.read(clientLocationGatewayProvider).settings(_access),
              ),
            ],
            if (_locationError != null)
              WeyonjeAlert(
                title: 'Location Unavailable',
                message: _locationError!,
              ),
            _heading('Service Details'),
            WeyonjeSelect<String>(
              initialValue: _toilet,
              label: const Text('Type of Toilet to Empty'),
              items: const [
                (value: 'PIT_LATRINE', label: 'Pit Latrine'),
                (value: 'SEPTIC_TANK', label: 'Septic Tank'),
              ],
              validator: (value) =>
                  value == null ? 'Select the type of toilet to empty.' : null,
              onChanged: _draftLocked
                  ? null
                  : (value) => setState(() => _toilet = value),
            ),
            _heading('Additional Contact Details'),
            FTextFormField(
              key: const Key('request-contact-name'),
              control: FTextFieldControl.managed(controller: _contactName),
              enabled: !_draftLocked,
              label: const Text('Contact Person (Name)'),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) &&
                      _contactPhone.text.trim().isNotEmpty
                  ? 'Supply the contact name or clear the telephone contact.'
                  : null,
            ),
            const SizedBox(height: 12),
            FTextFormField(
              key: const Key('request-contact-phone'),
              control: FTextFieldControl.managed(controller: _contactPhone),
              enabled: !_draftLocked,
              keyboardType: TextInputType.phone,
              label: const Text('Contact Person (Telephone Contact)'),
              validator: (value) =>
                  _contactName.text.trim().isNotEmpty &&
                      (value?.trim().isEmpty ?? true)
                  ? 'Enter the contact person’s telephone contact.'
                  : _phoneError,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              WeyonjeAlert(
                title: _submissionUncertain
                    ? 'Request Status Unconfirmed'
                    : 'Request Not Submitted',
                message: _error!,
              ),
            if (_submissionUncertain) ...[
              const Text(
                'Submission may have succeeded. Details are held unchanged so Retry cannot create a second request. Check My Requests before starting a different request.',
              ),
              WeyonjeButton(
                label: 'Check My Requests',
                kind: WeyonjeButtonKind.outline,
                onPressed: _submitting
                    ? null
                    : () => context.go('/client/requests'),
              ),
            ],
            WeyonjeButton(
              label: 'Submit Request',
              loading: _submitting,
              onPressed:
                  _checking ||
                      _access != ClientLocationAccess.ready ||
                      _locating ||
                      _profile == null
                  ? null
                  : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
