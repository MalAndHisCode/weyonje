import '../../../ui/weyonje_select.dart';
import 'package:forui/forui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../navigation/app_router.dart';
import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/workflow_providers.dart';
import '../domain/workflow_models.dart';
import 'workflow_widgets.dart';
import 'weyonje_map.dart';

class RequestServiceScreen extends ConsumerStatefulWidget {
  const RequestServiceScreen({super.key});
  @override
  ConsumerState<RequestServiceScreen> createState() =>
      _RequestServiceScreenState();
}

class _RequestServiceScreenState extends ConsumerState<RequestServiceScreen> {
  final _form = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  String _locationKind = 'TEXT';
  String? _toiletType;
  bool _asap = true;
  DateTime? _scheduled;
  double? _latitude;
  double? _longitude;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _location.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> _chooseLocation() async {
    final value = await context.push<Map<String, double>>(
      AppRoutes.locationPicker,
    );
    if (value != null && mounted) {
      setState(() {
        _latitude = value['latitude'];
        _longitude = value['longitude'];
        _locationKind = 'MAP_PIN';
      });
    }
  }

  Future<void> _chooseSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      initialDate: _scheduled ?? now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduled ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time != null && mounted) {
      setState(
        () => _scheduled = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_asap && _scheduled == null) {
      setState(() => _error = 'Choose the requested service date and time.');
      return;
    }
    if (_locationKind != 'TEXT' && (_latitude == null || _longitude == null)) {
      setState(() => _error = 'Choose or capture a valid location.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await ref
          .read(workflowRepositoryProvider)
          .createClientRequest({
            'locationKind': _locationKind,
            if (_locationKind == 'TEXT') 'locationText': _location.text.trim(),
            if (_locationKind != 'TEXT')
              'location': {'latitude': _latitude, 'longitude': _longitude},
            if (_toiletType != null) 'toiletType': _toiletType,
            if (_contactName.text.trim().isNotEmpty)
              'additionalContactName': _contactName.text.trim(),
            if (_contactPhone.text.trim().isNotEmpty)
              'additionalContactPhone': _contactPhone.text.trim(),
            'scheduleMode': _asap ? 'ASAP' : 'SCHEDULED',
            if (!_asap)
              'requestedServiceAt': _scheduled!.toUtc().toIso8601String(),
          });
      if (mounted) context.go('/client/requests/${request.id}');
    } on WorkflowException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Request a Service',
    showBack: true,
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            WeyonjeAlert(title: 'Request Not Submitted', message: _error!),
            const SizedBox(height: 16),
          ],
          Text('Location', style: Theme.of(context).textTheme.titleMedium),
          Column(
            children: [
              FRadio(
                value: _locationKind == 'TEXT',
                onChange: (_) => setState(() => _locationKind = 'TEXT'),
                label: const Text('Describe the location'),
              ),
              FRadio(
                value: _locationKind == 'MAP_PIN',
                onChange: (_) => _chooseLocation(),
                label: const Text('Choose a location pin'),
              ),
            ],
          ),
          if (_locationKind == 'TEXT')
            FTextFormField(
              control: FTextFieldControl.managed(controller: _location),
              label: Text('Location description'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter the service location.'
                  : null,
            ),
          if (_locationKind != 'TEXT')
            Text(
              _latitude == null
                  ? 'No pin selected.'
                  : '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
            ),
          const SizedBox(height: 16),
          WeyonjeSelect<String>(
            initialValue: _toiletType,
            label: Text('Toilet type (optional)'),
            items: const [
              (value: 'PIT_LATRINE', label: 'Pit latrine'),
              (value: 'SEPTIC_TANK', label: 'Septic tank'),
            ],
            onChanged: (value) => setState(() => _toiletType = value),
          ),
          const SizedBox(height: 16),
          FSwitch(
            value: _asap,
            onChange: (value) => setState(() => _asap = value),
            label: const Text('As soon as possible'),
            description: const Text(
              'Turn off to request a specific date and time.',
            ),
          ),
          if (!_asap)
            FButton(
              variant: FButtonVariant.outline,
              onPress: _chooseSchedule,
              child: Flexible(
                child: Text(
                  _scheduled == null
                      ? 'Choose Date and Time'
                      : '${_scheduled!}'.split('.').first,
                ),
              ),
            ),
          const SizedBox(height: 16),
          FTextFormField(
            control: FTextFieldControl.managed(controller: _contactName),
            label: Text('Additional contact name (optional)'),
          ),
          const SizedBox(height: 12),
          FTextFormField(
            control: FTextFieldControl.managed(controller: _contactPhone),
            keyboardType: TextInputType.phone,
            label: Text('Additional contact phone (optional)'),
            validator: (_) =>
                _contactName.text.trim().isEmpty ==
                    _contactPhone.text.trim().isEmpty
                ? null
                : 'Provide both additional contact name and phone.',
          ),
          const SizedBox(height: 24),
          WeyonjeButton(
            label: 'Submit Request',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    ),
  );
}

class RequestLocationPickerScreen extends ConsumerStatefulWidget {
  const RequestLocationPickerScreen({super.key});
  @override
  ConsumerState<RequestLocationPickerScreen> createState() =>
      _RequestLocationPickerScreenState();
}

class _RequestLocationPickerScreenState
    extends ConsumerState<RequestLocationPickerScreen> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _search = TextEditingController();
  bool _loading = false;
  String? _error;
  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _device() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final point = await ref.read(deviceLocationProvider).current();
      if (mounted) {
        setState(() {
          _latitude.text = '${point.latitude}';
          _longitude.text = '${point.longitude}';
        });
      }
    } on WorkflowException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirm() {
    final latitude = double.tryParse(_latitude.text);
    final longitude = double.tryParse(_longitude.text);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      setState(() => _error = 'Enter valid latitude and longitude values.');
      return;
    }
    context.pop({'latitude': latitude, 'longitude': longitude});
  }

  @override
  Widget build(BuildContext context) {
    final maps = ref.watch(mapSelectionProvider);
    return WeyonjePage(
      title: 'Request Location',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeyonjeAlert(
            title: maps.configured
                ? 'Select a Location'
                : 'Google Maps Unavailable',
            message: maps.configured
                ? 'Tap the map, use your device location, or enter coordinates. Coordinate text remains available for accessibility.'
                : 'Google Maps resources and credentials have not been authorised. No map or fabricated place data is shown.',
          ),
          if (maps.configured) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FTextField(
                    control: FTextFieldControl.managed(controller: _search),
                    textInputAction: TextInputAction.search,
                    label: Text('Search address or place'),
                    onSubmit: (_) => _searchPlaces(),
                  ),
                ),
                IconButton(
                  tooltip: 'Search places',
                  onPressed: _loading ? null : _searchPlaces,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 12),
            WeyonjeMap(
              destinationLatitude: double.tryParse(_latitude.text) ?? 0.3476,
              destinationLongitude: double.tryParse(_longitude.text) ?? 32.5825,
              onSelected: (point) async {
                setState(() {
                  _latitude.text = point.latitude.toStringAsFixed(6);
                  _longitude.text = point.longitude.toStringAsFixed(6);
                });
                try {
                  final address = await ref
                      .read(workflowRepositoryProvider)
                      .reverseGeocode(point.latitude, point.longitude);
                  if (mounted && address != null) _search.text = address;
                } catch (_) {
                  // Coordinates remain usable when geocoding is offline.
                }
              },
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            WeyonjeAlert(title: 'Location Unavailable', message: _error!),
          ],
          const SizedBox(height: 16),
          WeyonjeButton(
            label: 'Use My Current Location',
            loading: _loading,
            onPressed: _device,
          ),
          const SizedBox(height: 16),
          FTextField(
            control: FTextFieldControl.managed(controller: _latitude),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            label: Text('Latitude'),
          ),
          const SizedBox(height: 12),
          FTextField(
            control: FTextFieldControl.managed(controller: _longitude),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            label: Text('Longitude'),
          ),
          const SizedBox(height: 20),
          WeyonjeButton(label: 'Confirm Location', onPressed: _confirm),
        ],
      ),
    );
  }

  Future<void> _searchPlaces() async {
    if (_search.text.trim().length < 2) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(workflowRepositoryProvider)
          .searchPlaces(_search.text.trim());
      if (!mounted) return;
      if (results.isEmpty) {
        setState(() => _error = 'No matching places were found.');
        return;
      }
      final selected = await showModalBottomSheet<MapPlace>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            children: results
                .map(
                  (place) => FTile(
                    title: Text(place.name),
                    subtitle: Text(
                      '${place.address}\n${place.latitude}, ${place.longitude}',
                    ),
                    onPress: () => Navigator.pop(context, place),
                  ),
                )
                .toList(),
          ),
        ),
      );
      if (selected != null) {
        setState(() {
          _search.text = selected.address;
          _latitude.text = selected.latitude.toStringAsFixed(6);
          _longitude.text = selected.longitude.toStringAsFixed(6);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class ClientRequestsScreen extends ConsumerStatefulWidget {
  const ClientRequestsScreen({super.key});
  @override
  ConsumerState<ClientRequestsScreen> createState() =>
      _ClientRequestsScreenState();
}

class _ClientRequestsScreenState extends ConsumerState<ClientRequestsScreen> {
  late Future<List<ServiceRequestSummary>> _load;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      _load = ref.read(workflowRepositoryProvider).clientRequests();
  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'My Requests',
    showBack: true,
    child: FutureBuilder<List<ServiceRequestSummary>>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: FCircularProgress());
        }
        if (snapshot.hasError) {
          return WorkflowErrorView(
            error: snapshot.error!,
            onRetry: () => setState(_reload),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WeyonjeButton(
              label: 'Request a Service',
              onPressed: () => context
                  .push(AppRoutes.clientRequestNew)
                  .then((_) => setState(_reload)),
            ),
            const SizedBox(height: 16),
            if (snapshot.requireData.isEmpty)
              const Text('You have no service requests yet.'),
            ...snapshot.requireData.map(
              (item) => RequestSummaryCard(
                request: item,
                onTap: () => context
                    .push('/client/requests/${item.id}')
                    .then((_) => setState(_reload)),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class ClientRequestDetailsScreen extends ConsumerStatefulWidget {
  const ClientRequestDetailsScreen({required this.requestId, super.key});
  final String requestId;
  @override
  ConsumerState<ClientRequestDetailsScreen> createState() =>
      _ClientRequestDetailsScreenState();
}

class _ClientRequestDetailsScreenState
    extends ConsumerState<ClientRequestDetailsScreen> {
  late Future<ServiceRequestDetail> _load;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _load = ref
      .read(workflowRepositoryProvider)
      .clientRequest(widget.requestId);
  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Request Details',
    showBack: true,
    child: FutureBuilder<ServiceRequestDetail>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: FCircularProgress());
        }
        if (snapshot.hasError) {
          return WorkflowErrorView(
            error: snapshot.error!,
            onRetry: () => setState(_reload),
          );
        }
        final item = snapshot.requireData;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.reference,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Status: ${humanStatus(item.status)}'),
            Text('Location: ${item.locationLabel}'),
            Text(
              'Requested: ${scheduleLabel(item.scheduleMode, item.requestedServiceAt)}',
            ),
            if (item.providerName != null)
              Text('Provider: ${item.providerName}'),
            if (item.agreedPriceUgx != null)
              Text('Agreed price: UGX ${item.agreedPriceUgx}'),
            if (item.followUpStatus != null) ...[
              const SizedBox(height: 12),
              WeyonjeAlert(
                title: 'Follow-Up Case Recorded',
                message:
                    'KCCA follow-up: ${humanStatus(item.followUpStatus!)}. Disposal remains separate when waste was collected.',
              ),
            ],
            const SizedBox(height: 20),
            if (item.status == 'COLLECTION_REPORTED')
              WeyonjeButton(
                label: 'Confirm Collection and Rate',
                onPressed: () => context
                    .push('/client/requests/${item.id}/feedback')
                    .then((_) => setState(_reload)),
              ),
            if (item.journeyToRequest != null &&
                item.journeyToRequest!.status != 'COMPLETED')
              WeyonjeButton(
                label: 'Track Provider',
                kind: WeyonjeButtonKind.outline,
                onPressed: () =>
                    context.push('/tracking/${item.id}?phase=TO_REQUEST'),
              ),
          ],
        );
      },
    ),
  );
}

class CollectionFeedbackScreen extends ConsumerStatefulWidget {
  const CollectionFeedbackScreen({required this.requestId, super.key});
  final String requestId;
  @override
  ConsumerState<CollectionFeedbackScreen> createState() =>
      _CollectionFeedbackScreenState();
}

class _CollectionFeedbackScreenState
    extends ConsumerState<CollectionFeedbackScreen> {
  final _feedback = TextEditingController();
  String _outcome = 'COMPLETED';
  int _rating = 5;
  bool _loading = false;
  String? _error;
  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_feedback.text.trim().isEmpty) {
      setState(() => _error = 'Enter collection feedback.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(workflowRepositoryProvider)
          .submitFeedback(
            widget.requestId,
            outcome: _outcome,
            feedback: _feedback.text.trim(),
            rating: _rating,
          );
      if (mounted) context.pop();
    } on WorkflowException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Collection Feedback',
    showBack: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          WeyonjeAlert(title: 'Feedback Not Recorded', message: _error!),
        WeyonjeSelect<String>(
          initialValue: _outcome,
          label: Text('Collection outcome'),
          items: const [
            (value: 'COMPLETED', label: 'Completed'),
            (
              value: 'LEFT_INCOMPLETE',
              label: 'Waste collected, but left incomplete',
            ),
            (value: 'NOT_DONE_AT_ALL', label: 'Not done at all'),
          ],
          onChanged: (value) => setState(() => _outcome = value!),
        ),
        const SizedBox(height: 16),
        Text(
          'Rating: $_rating of 5',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        FSlider(
          control: FSliderControl.managedDiscrete(
            initial: FSliderValue(max: (_rating - 1) / 4),
            onChange: (value) =>
                setState(() => _rating = (value.max * 4).round() + 1),
          ),
          marks: const [
            FSliderMark(value: 0),
            FSliderMark(value: 0.25),
            FSliderMark(value: 0.5),
            FSliderMark(value: 0.75),
            FSliderMark(value: 1),
          ],
          trackHitRegionCrossExtent: 48,
          semanticValueFormatterCallback: (value) =>
              '${(value * 4).round() + 1} of 5',
          tooltipBuilder: (_, value) => Text('${(value * 4).round() + 1}'),
        ),
        FTextField(
          control: FTextFieldControl.managed(controller: _feedback),
          maxLines: 5,
          label: Text('Feedback'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Negative feedback creates a separate KCCA follow-up case. When waste was collected, it does not stop the disposal workflow.',
        ),
        const SizedBox(height: 20),
        WeyonjeButton(
          label: 'Submit Feedback',
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    ),
  );
}
