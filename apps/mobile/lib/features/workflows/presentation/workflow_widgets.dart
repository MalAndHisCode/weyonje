import 'package:flutter/material.dart';

import '../../../ui/weyonje_alert.dart';
import '../domain/workflow_models.dart';

String humanStatus(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

String scheduleLabel(String mode, DateTime? time) => mode == 'ASAP'
    ? 'As soon as possible'
    : time == null
    ? 'Scheduled time unavailable'
    : '${time.toLocal()}'.split('.').first;

class WorkflowErrorView extends StatelessWidget {
  const WorkflowErrorView({
    required this.error,
    required this.onRetry,
    super.key,
  });
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      WeyonjeAlert(
        title: 'Could not load this work',
        message: error is WorkflowException
            ? (error as WorkflowException).message
            : 'Check your connection and try again.',
      ),
      const SizedBox(height: 16),
      FilledButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}

class RequestSummaryCard extends StatelessWidget {
  const RequestSummaryCard({
    required this.request,
    required this.onTap,
    super.key,
  });
  final ServiceRequestSummary request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      title: Text(request.reference),
      subtitle: Text(
        '${humanStatus(request.status)}\n${request.locationLabel}\n${scheduleLabel(request.scheduleMode, request.requestedServiceAt)}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class CountCard extends StatelessWidget {
  const CountCard({required this.label, required this.value, super.key});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
