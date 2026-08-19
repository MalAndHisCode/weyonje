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
    title: 'Client dashboard',
    child: FutureBuilder<WorkflowDashboard>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
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
                  label: 'Action needed',
                  value: data.actionRequiredCount,
                ),
              ],
            ),
            const SizedBox(height: 16),
            WeyonjeButton(
              label: 'Request a service',
              onPressed: () => context
                  .push(AppRoutes.clientRequestNew)
                  .then((_) => _reload()),
            ),
            const SizedBox(height: 10),
            WeyonjeButton(
              label: 'My requests',
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
              'Recent requests',
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
            TextButton(
              onPressed: () =>
                  ref.read(launchControllerProvider.notifier).signOut(),
              child: const Text('Sign out'),
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
    title: 'Provider work dashboard',
    child: FutureBuilder<WorkflowDashboard>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
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
                CountCard(label: 'My jobs', value: data.activeCount),
                CountCard(
                  label: 'Action needed',
                  value: data.actionRequiredCount,
                ),
              ],
            ),
            const SizedBox(height: 16),
            WeyonjeButton(
              label: 'Pending service requests',
              onPressed: () => context
                  .push(AppRoutes.providerPending)
                  .then((_) => _reload()),
            ),
            const SizedBox(height: 10),
            WeyonjeButton(
              label: 'My jobs',
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
            TextButton(
              onPressed: () =>
                  ref.read(launchControllerProvider.notifier).signOut(),
              child: const Text('Sign out'),
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
    _load = ref.read(workflowRepositoryProvider).kccaMonitoring();
  }

  void _reload() => setState(
    () => _load = ref.read(workflowRepositoryProvider).kccaMonitoring(),
  );
  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'KCCA monitoring',
    child: FutureBuilder<List<ServiceRequestSummary>>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return WorkflowErrorView(error: snapshot.error!, onRetry: _reload);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Read-only mobile monitoring. Operational administration remains outside this app.',
            ),
            const SizedBox(height: 12),
            WeyonjeButton(
              label: 'Notifications',
              kind: WeyonjeButtonKind.outline,
              onPressed: () => context.push(AppRoutes.notifications),
            ),
            const SizedBox(height: 16),
            if (snapshot.requireData.isEmpty)
              const Text('No journeys currently require mobile monitoring.'),
            ...snapshot.requireData.map(
              (request) => RequestSummaryCard(
                request: request,
                onTap: () => context.push(
                  '/tracking/${request.id}?phase=${request.status == 'COLLECTION_COMPLETED' || request.status == 'COMPLETED' ? 'TO_DISPOSAL' : 'TO_REQUEST'}',
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(launchControllerProvider.notifier).signOut(),
              child: const Text('Sign out'),
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
          return const Center(child: CircularProgressIndicator());
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
                (item) => Card(
                  child: ListTile(
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.readAt == null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('${item.message}\n${item.createdAt}'),
                    onTap: () async {
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
