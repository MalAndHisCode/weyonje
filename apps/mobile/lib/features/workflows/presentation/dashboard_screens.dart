import 'package:forui/forui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../navigation/app_router.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../../auth/application/launch_controller.dart';
import '../application/workflow_providers.dart';
import '../domain/workflow_models.dart';
import 'workflow_widgets.dart';

class ClientDashboardScreen extends ConsumerStatefulWidget {
  const ClientDashboardScreen({super.key});
  @override
  ConsumerState<ClientDashboardScreen> createState() =>
      _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  late Future<WorkflowDashboard> _load;
  @override
  void initState() {
    super.initState();
    _load = ref.read(workflowRepositoryProvider).clientDashboard();
  }

  void _reload() => setState(
    () => _load = ref.read(workflowRepositoryProvider).clientDashboard(),
  );

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Client Dashboard',
    child: FutureBuilder<WorkflowDashboard>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: FCircularProgress());
        }
        if (snapshot.hasError) {
          return WorkflowErrorView(error: snapshot.error!, onRetry: _reload);
        }
        final data = snapshot.requireData;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CountCard(label: 'Pending', value: data.pendingCount),
                CountCard(label: 'Active', value: data.activeCount),
                CountCard(
                  label: 'Action Needed',
                  value: data.actionRequiredCount,
                ),
              ],
            ),
            const SizedBox(height: 16),
            WeyonjeButton(
              label: 'Request for a Service',
              onPressed: () => context
                  .push(AppRoutes.clientRequestNew)
                  .then((_) => _reload()),
            ),
            const SizedBox(height: 10),
            WeyonjeButton(
              label: 'My Requests',
              kind: WeyonjeButtonKind.outline,
              onPressed: () =>
                  context.push(AppRoutes.clientRequests).then((_) => _reload()),
            ),
            const SizedBox(height: 10),
            WeyonjeButton(
              label: 'Notifications',
              kind: WeyonjeButtonKind.outline,
              onPressed: () => context.push(AppRoutes.notifications),
            ),
            const SizedBox(height: 24),
            Text(
              'Recent Requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (data.recentRequests.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('You have no service requests yet.'),
              ),
            ...data.recentRequests
                .take(5)
                .map(
                  (request) => RequestSummaryCard(
                    request: request,
                    onTap: () => context
                        .push('/client/requests/${request.id}')
                        .then((_) => _reload()),
                  ),
                ),
            const SizedBox(height: 16),
            FButton(
              variant: FButtonVariant.ghost,
              onPress: () =>
                  ref.read(launchControllerProvider.notifier).signOut(),
              child: Flexible(child: const Text('Sign Out')),
            ),
          ],
        );
      },
    ),
  );
}

class ProviderDashboardScreen extends ConsumerStatefulWidget {
  const ProviderDashboardScreen({super.key});
  @override
  ConsumerState<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState
    extends ConsumerState<ProviderDashboardScreen> {
  late Future<WorkflowDashboard> _load;
  @override
  void initState() {
    super.initState();
    _load = ref.read(workflowRepositoryProvider).providerDashboard();
  }

  void _reload() => setState(
    () => _load = ref.read(workflowRepositoryProvider).providerDashboard(),
  );
  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Provider Work Dashboard',
    child: FutureBuilder<WorkflowDashboard>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: FCircularProgress());
        }
        if (snapshot.hasError) {
          return WorkflowErrorView(error: snapshot.error!, onRetry: _reload);
        }
        final data = snapshot.requireData;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.actorNumber != null)
              Text(
                'Provider ${data.actorNumber}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                CountCard(label: 'Available', value: data.pendingCount),
                CountCard(label: 'My Jobs', value: data.activeCount),
                CountCard(
                  label: 'Action Needed',
                  value: data.actionRequiredCount,
                ),
              ],
            ),
            const SizedBox(height: 16),
            WeyonjeButton(
              label: 'Pending Service Requests',
              onPressed: () => context
                  .push(AppRoutes.providerPending)
                  .then((_) => _reload()),
            ),
            const SizedBox(height: 10),
            WeyonjeButton(
              label: 'My Jobs',
              kind: WeyonjeButtonKind.outline,
              onPressed: () =>
                  context.push(AppRoutes.providerJobs).then((_) => _reload()),
            ),
            const SizedBox(height: 10),
            WeyonjeButton(
              label: 'Notifications',
              kind: WeyonjeButtonKind.outline,
              onPressed: () => context.push(AppRoutes.notifications),
            ),
            const SizedBox(height: 24),
            ...data.recentRequests
                .take(5)
                .map(
                  (request) => RequestSummaryCard(
                    request: request,
                    onTap: () => context
                        .push('/provider/jobs/${request.id}')
                        .then((_) => _reload()),
                  ),
                ),
            FButton(
              variant: FButtonVariant.ghost,
              onPress: () =>
                  ref.read(launchControllerProvider.notifier).signOut(),
              child: Flexible(child: const Text('Sign Out')),
            ),
          ],
        );
      },
    ),
  );
}

class KccaMonitoringDashboardScreen extends ConsumerStatefulWidget {
  const KccaMonitoringDashboardScreen({super.key});
  @override
  ConsumerState<KccaMonitoringDashboardScreen> createState() =>
      _KccaMonitoringDashboardScreenState();
}

class _KccaMonitoringDashboardScreenState
    extends ConsumerState<KccaMonitoringDashboardScreen> {
  late Future<List<ServiceRequestSummary>> _load;
  @override
  void initState() {
    super.initState();
    final launch = ref.read(launchControllerProvider);
    _load =
        launch is LaunchAuthenticated && launch.actor.mobileMonitoringPermitted
        ? ref.read(workflowRepositoryProvider).kccaMonitoring()
        : Future.value(const <ServiceRequestSummary>[]);
  }

  void _reload() => setState(
    () => _load = ref.read(workflowRepositoryProvider).kccaMonitoring(),
  );
  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'KCCA Monitoring',
    child: FutureBuilder<List<ServiceRequestSummary>>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: FCircularProgress());
        }
        if (snapshot.hasError) {
          return WorkflowErrorView(error: snapshot.error!, onRetry: _reload);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'KCCA monitoring and authorised operational administration.',
            ),
            const SizedBox(height: 12),
            if (ref.watch(launchControllerProvider) case LaunchAuthenticated(
              :final actor,
            )) ...[
              if (actor.providerApprovalPermitted) ...[
                WeyonjeButton(
                  label: 'Provider Administration',
                  onPressed: () =>
                      context.push(AppRoutes.kccaProviderAdministration),
                ),
                const SizedBox(height: 10),
              ],
              if (actor.callCentreOperationsPermitted) ...[
                WeyonjeButton(
                  label: 'Manual Call Centre Entry',
                  onPressed: () => context.push(AppRoutes.kccaCallCentre),
                ),
                const SizedBox(height: 10),
                WeyonjeButton(
                  label: 'Disposal-Site Administration',
                  kind: WeyonjeButtonKind.outline,
                  onPressed: () => context.push(AppRoutes.kccaDisposalSites),
                ),
                const SizedBox(height: 10),
              ],
            ],
            WeyonjeButton(
              label: 'Notifications',
              kind: WeyonjeButtonKind.outline,
              onPressed: () => context.push(AppRoutes.notifications),
            ),
            const SizedBox(height: 16),
            if (snapshot.requireData.isEmpty)
              Text(switch (ref.watch(launchControllerProvider)) {
                LaunchAuthenticated(:final actor)
                    when !actor.mobileMonitoringPermitted =>
                  'This account does not have mobile journey-monitoring permission.',
                _ => 'No journeys currently require mobile monitoring.',
              }),
            ...snapshot.requireData.map(
              (request) => RequestSummaryCard(
                request: request,
                onTap: () => context.push(
                  '/tracking/${request.id}?phase=${request.status == 'COLLECTION_COMPLETED' || request.status == 'COMPLETED' ? 'TO_DISPOSAL' : 'TO_REQUEST'}',
                ),
              ),
            ),
            FButton(
              variant: FButtonVariant.ghost,
              onPress: () =>
                  ref.read(launchControllerProvider.notifier).signOut(),
              child: Flexible(child: const Text('Sign Out')),
            ),
          ],
        );
      },
    ),
  );
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<List<OperationalNotification>> _load;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      _load = ref.read(workflowRepositoryProvider).notifications();
  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Notifications',
    showBack: true,
    child: FutureBuilder<List<OperationalNotification>>(
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
          return const Text('No notifications yet.');
        }
        return Column(
          children: snapshot.requireData
              .map(
                (item) => FCard(
                  child: FTile(
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.readAt == null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('${item.message}\n${item.createdAt}'),
                    onPress: () async {
                      await ref
                          .read(workflowRepositoryProvider)
                          .markNotificationRead(item.id);
                      if (mounted) setState(_reload);
                    },
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}
