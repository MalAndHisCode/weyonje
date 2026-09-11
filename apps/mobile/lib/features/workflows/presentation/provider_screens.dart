import 'package:forui/forui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/workflow_providers.dart';
import '../domain/workflow_models.dart';
import 'workflow_widgets.dart';

class PendingServiceRequestsScreen extends ConsumerStatefulWidget {
  const PendingServiceRequestsScreen({super.key});
  @override
  ConsumerState<PendingServiceRequestsScreen> createState() =>
      _PendingServiceRequestsScreenState();
}

class _PendingServiceRequestsScreenState
    extends ConsumerState<PendingServiceRequestsScreen>
    with WidgetsBindingObserver {
  late Future<List<ProviderPendingRequest>> _load;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(_reload);
  }

  void _reload() =>
      _load = ref.read(workflowRepositoryProvider).pendingProviderRequests();
  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Pending Service Requests',
    showBack: true,
    child: FutureBuilder<List<ProviderPendingRequest>>(
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
        if (snapshot.requireData.isEmpty) {
          return Column(
            children: [
              const Text('No eligible requests are currently available.'),
              WeyonjeButton(
                label: 'Refresh Requests',
                kind: WeyonjeButtonKind.outline,
                onPressed: () => setState(_reload),
              ),
            ],
          );
        }
        return Column(
          children: [
            WeyonjeButton(
              label: 'Refresh Requests',
              kind: WeyonjeButtonKind.outline,
              onPressed: () => setState(_reload),
            ),
            ...snapshot.requireData.map(
              (item) => FCard(
                child: FTile(
                  title: Text(item.reference),
                  subtitle: Text(
                    '${item.origin == 'CALL_CENTRE' ? 'Call Centre assignment' : 'Marketplace request'}\n${item.locationLabel}\n${scheduleLabel(item.scheduleMode, item.requestedServiceAt)}${item.toiletType == null ? '' : '\n${humanStatus(item.toiletType!)}'}',
                  ),

                  suffix: const Icon(Icons.chevron_right),
                  onPress: () => context
                      .push('/provider/requests/${item.id}')
                      .then((_) => setState(_reload)),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class ProviderRequestDetailsScreen extends ConsumerStatefulWidget {
  const ProviderRequestDetailsScreen({required this.requestId, super.key});
  final String requestId;
  @override
  ConsumerState<ProviderRequestDetailsScreen> createState() =>
      _ProviderRequestDetailsScreenState();
}

class _ProviderRequestDetailsScreenState
    extends ConsumerState<ProviderRequestDetailsScreen> {
  final _price = TextEditingController();
  late Future<ServiceRequestDetail> _load;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _reload() => _load = ref
      .read(workflowRepositoryProvider)
      .providerRequest(widget.requestId);

  Future<void> _accept(ServiceRequestDetail request) async {
    final price = request.origin == 'MOBILE_APP'
        ? int.tryParse(_price.text.trim())
        : null;
    if (request.origin == 'MOBILE_APP' && price == null) {
      setState(() => _error = 'Enter a non-negative whole-number UGX price.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(workflowRepositoryProvider)
          .acceptRequest(request.id, agreedPriceUgx: price);
      if (mounted) context.go('/provider/jobs/${request.id}');
    } on WorkflowException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code == 'REQUEST_ALREADY_ACCEPTED'
              ? 'Another Provider already accepted this request. Refresh the marketplace.'
              : error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject(ServiceRequestDetail request) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(workflowRepositoryProvider).rejectRequest(request.id);
      if (mounted) context.pop();
    } on WorkflowException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
            if (_error != null) ...[
              WeyonjeAlert(title: 'Action Not Completed', message: _error!),
              const SizedBox(height: 12),
            ],
            Text(
              item.reference,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              item.origin == 'CALL_CENTRE'
                  ? 'Assigned by Call Centre'
                  : 'Open marketplace request',
            ),
            const SizedBox(height: 10),
            Text('Location: ${item.locationLabel}'),
            Text(
              'Requested: ${scheduleLabel(item.scheduleMode, item.requestedServiceAt)}',
            ),
            if (item.toiletType != null)
              Text('Toilet: ${humanStatus(item.toiletType!)}'),
            const SizedBox(height: 12),
            const Text(
              'Exact location and Client contact information are disclosed only after acceptance.',
            ),
            if (item.origin == 'MOBILE_APP') ...[
              const SizedBox(height: 16),
              FTextField(
                control: FTextFieldControl.managed(controller: _price),
                keyboardType: TextInputType.number,
                label: Text('Agreed price (whole UGX)'),
              ),
            ],
            const SizedBox(height: 20),
            WeyonjeButton(
              label: 'Accept Request',
              loading: _loading,
              onPressed: () => _accept(item),
            ),
            if (item.origin == 'CALL_CENTRE') ...[
              const SizedBox(height: 10),
              WeyonjeButton(
                label: 'Reject Assignment',
                kind: WeyonjeButtonKind.outline,
                loading: _loading,
                onPressed: () => _reject(item),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class ProviderJobsScreen extends ConsumerStatefulWidget {
  const ProviderJobsScreen({super.key});
  @override
  ConsumerState<ProviderJobsScreen> createState() => _ProviderJobsScreenState();
}

class _ProviderJobsScreenState extends ConsumerState<ProviderJobsScreen> {
  late Future<List<ServiceRequestSummary>> _load;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _load = ref.read(workflowRepositoryProvider).providerJobs();
  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'My Jobs',
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
        if (snapshot.requireData.isEmpty) {
          return const Text('You have no accepted jobs yet.');
        }
        return Column(
          children: snapshot.requireData
              .map(
                (item) => RequestSummaryCard(
                  request: item,
                  onTap: () => context
                      .push('/provider/jobs/${item.id}')
                      .then((_) => setState(_reload)),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class ProviderJobDetailsScreen extends ConsumerStatefulWidget {
  const ProviderJobDetailsScreen({required this.requestId, super.key});
  final String requestId;
  @override
  ConsumerState<ProviderJobDetailsScreen> createState() =>
      _ProviderJobDetailsScreenState();
}

class _ProviderJobDetailsScreenState
    extends ConsumerState<ProviderJobDetailsScreen> {
  late Future<ServiceRequestDetail> _load;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _load = ref
      .read(workflowRepositoryProvider)
      .providerJob(widget.requestId);
  Future<void> _command(Future<ServiceRequestDetail> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) setState(_reload);
    } on WorkflowException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Job Details',
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
            if (_error != null) ...[
              WeyonjeAlert(title: 'Action Not Completed', message: _error!),
              const SizedBox(height: 12),
            ],
            Text(
              item.reference,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('Status: ${humanStatus(item.status)}'),
            Text('Client: ${item.clientName}'),
            if (item.clientPhone != null)
              Text('Client phone: ${item.clientPhone}'),
            Text('Location: ${item.locationLabel}'),
            if (item.agreedPriceUgx != null)
              Text('Agreed price: UGX ${item.agreedPriceUgx}'),
            if (item.disposalSite != null)
              Text(
                'KCCA disposal site: ${item.disposalSite!.name}\n${item.disposalSite!.address}',
              ),
            if (item.followUpStatus != null) ...[
              const SizedBox(height: 12),
              WeyonjeAlert(
                title: 'Separate Follow-Up Case',
                message:
                    'KCCA follow-up is ${humanStatus(item.followUpStatus!)}. Continue disposal if the recorded outcome confirms waste was collected.',
              ),
            ],
            const SizedBox(height: 20),
            if (item.latitude == null && item.status == 'ACCEPTED') ...[
              const WeyonjeAlert(
                title: 'Coordinate Tracking Unavailable',
                message:
                    'This request uses a text location. Initiate the job normally; Weyonje will not fabricate a map or coordinate journey.',
              ),
              const SizedBox(height: 12),
            ],
            if (item.status == 'ACCEPTED')
              WeyonjeButton(
                label: item.latitude == null
                    ? 'Initiate Job'
                    : 'Initiate Job and Location Tracking',
                loading: _loading,
                onPressed: () =>
                    _command(
                      () => ref
                          .read(workflowRepositoryProvider)
                          .startJourney(item.id, 'TO_REQUEST'),
                    ).then((_) {
                      if (context.mounted && item.latitude != null) {
                        context.push(
                          '/tracking/${item.id}?phase=TO_REQUEST&provider=true',
                        );
                      }
                    }),
              ),
            if (item.status == 'ACTIVE') ...[
              if (item.latitude != null)
                WeyonjeButton(
                  label: 'Open Journey Tracking',
                  kind: WeyonjeButtonKind.outline,
                  onPressed: () => context.push(
                    '/tracking/${item.id}?phase=TO_REQUEST&provider=true',
                  ),
                ),
              if (item.latitude != null) const SizedBox(height: 10),
              WeyonjeButton(
                label: 'Report Collection Completed',
                loading: _loading,
                onPressed: () => _command(
                  () => ref
                      .read(workflowRepositoryProvider)
                      .reportCollection(item.id),
                ),
              ),
            ],
            if (item.status == 'COLLECTION_REPORTED')
              const WeyonjeAlert(
                title: 'Waiting for Collection Confirmation',
                message:
                    'The Client or Call Centre must record the actual outcome before disposal can proceed.',
              ),
            if (item.status == 'FOLLOW_UP_REQUIRED')
              const WeyonjeAlert(
                title: 'Follow-Up Required',
                message:
                    'Waste was recorded as not collected, so disposal cannot begin. KCCA follow-up is separate.',
              ),
            if (item.status == 'COLLECTION_COMPLETED' &&
                item.disposalJourney == null)
              WeyonjeButton(
                label: 'Start Disposal Journey',
                loading: _loading,
                onPressed: item.disposalSite == null
                    ? null
                    : () =>
                          _command(
                            () => ref
                                .read(workflowRepositoryProvider)
                                .startJourney(item.id, 'TO_DISPOSAL'),
                          ).then((_) {
                            if (context.mounted) {
                              context.push(
                                '/tracking/${item.id}?phase=TO_DISPOSAL&provider=true',
                              );
                            }
                          }),
              ),
            if (item.status == 'COLLECTION_COMPLETED' &&
                item.disposalJourney != null) ...[
              WeyonjeButton(
                label: 'Open Disposal Tracking',
                kind: WeyonjeButtonKind.outline,
                onPressed: () => context.push(
                  '/tracking/${item.id}?phase=TO_DISPOSAL&provider=true',
                ),
              ),
              if (item.disposalJourney!.status == 'ARRIVED') ...[
                const SizedBox(height: 10),
                WeyonjeButton(
                  label: 'Confirm Disposal Completed',
                  loading: _loading,
                  onPressed: () => _command(
                    () => ref
                        .read(workflowRepositoryProvider)
                        .completeDisposal(item.id),
                  ),
                ),
              ],
            ],
            if (item.status == 'COMPLETED')
              const WeyonjeAlert(
                title: 'Job Complete',
                message:
                    'The collection outcome and disposal completion are recorded.',
              ),
          ],
        );
      },
    ),
  );
}
