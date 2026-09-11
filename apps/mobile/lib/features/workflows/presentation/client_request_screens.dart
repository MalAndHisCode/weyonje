export 'request_service_screen.dart';
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
export 'request_location_picker_screen.dart';

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
