import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/workflow_providers.dart';
import '../domain/workflow_models.dart';
import 'workflow_widgets.dart';

class ProviderAdministrationScreen extends ConsumerStatefulWidget {
  const ProviderAdministrationScreen({super.key});
  @override
  ConsumerState<ProviderAdministrationScreen> createState() =>
      _ProviderAdministrationScreenState();
}

class _ProviderAdministrationScreenState
    extends ConsumerState<ProviderAdministrationScreen> {
  String _status = 'PENDING';
  late Future<List<ProviderAdministration>> _load;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      _load = ref.read(workflowRepositoryProvider).providers(_status);

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Provider administration',
    showBack: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Review ESS registration details and manage Provider eligibility. Every decision is retained in history.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(
            labelText: 'Provider status',
            border: OutlineInputBorder(),
          ),
          items:
              const ['PENDING', 'APPROVED', 'REJECTED', 'INACTIVE', 'DISABLED']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
          onChanged: (value) => setState(() {
            _status = value!;
            _reload();
          }),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<ProviderAdministration>>(
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
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No Providers have this status.'),
              );
            }
            return Column(
              children: snapshot.requireData.map(_providerCard).toList(),
            );
          },
        ),
      ],
    ),
  );

  Widget _providerCard(ProviderAdministration provider) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            provider.companyName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('ESS licence: ${provider.essLicenseNumber}'),
          Text(
            'Status: ${provider.status} • ${provider.active ? 'Active' : 'Not active'}',
          ),
          Text(provider.workAddress),
          Text('${provider.email}\n${provider.phoneNumber}'),
          Text('History entries: ${provider.history.length}'),
          const SizedBox(height: 12),
          if (provider.status == 'PENDING') ...[
            WeyonjeButton(
              label: 'Approve Provider',
              onPressed: () => _confirm(provider, 'APPROVED', decision: true),
            ),
            TextButton(
              onPressed: () => _confirm(provider, 'REJECTED', decision: true),
              child: const Text('Reject with reason'),
            ),
          ] else ...[
            WeyonjeButton(
              label: provider.status == 'APPROVED'
                  ? 'Deactivate Provider'
                  : 'Activate Provider',
              kind: WeyonjeButtonKind.outline,
              onPressed: () => _confirm(
                provider,
                provider.status == 'APPROVED' ? 'INACTIVE' : 'APPROVED',
              ),
            ),
            if (provider.status != 'DISABLED')
              TextButton(
                onPressed: () => _confirm(provider, 'DISABLED'),
                child: const Text('Disable with reason'),
              ),
          ],
        ],
      ),
    ),
  );

  Future<void> _confirm(
    ProviderAdministration provider,
    String status, {
    bool decision = false,
  }) async {
    final reason = TextEditingController();
    final requiresReason = status == 'REJECTED' || status == 'DISABLED';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm $status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Change ${provider.companyName} to $status?'),
            if (requiresReason) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (accepted != true || (requiresReason && reason.text.trim().isEmpty)) {
      return;
    }
    try {
      final repository = ref.read(workflowRepositoryProvider);
      if (decision) {
        await repository.decideProvider(
          provider.userId,
          status,
          reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
        );
      } else {
        await repository.changeProviderStatus(
          provider.userId,
          status,
          reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
        );
      }
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      reason.dispose();
    }
  }
}

class CallCentreAdministrationScreen extends ConsumerStatefulWidget {
  const CallCentreAdministrationScreen({super.key});
  @override
  ConsumerState<CallCentreAdministrationScreen> createState() =>
      _CallCentreAdministrationScreenState();
}

class _CallCentreAdministrationScreenState
    extends ConsumerState<CallCentreAdministrationScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _location = TextEditingController();
  final _price = TextEditingController();
  String _schedule = 'ASAP';
  String? _clientId;
  String? _providerId;
  bool _busy = false;
  String? _message;
  late Future<List<ServiceRequestSummary>> _requests;
  late Future<List<EligibleProvider>> _providers;

  @override
  void initState() {
    super.initState();
    _reload();
    _providers = ref.read(workflowRepositoryProvider).callCentreProviders();
  }

  void _reload() =>
      _requests = ref.read(workflowRepositoryProvider).callCentreRequests();

  @override
  void dispose() {
    for (final controller in [_name, _phone, _email, _location, _price]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Manual Call Centre entry',
    showBack: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter a request received manually through the KCCA Call Centre. This is not an external Call Centre system.',
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _findClient,
          child: const Text('Find an existing Client'),
        ),
        for (final field in [
          (_name, 'Client name', TextInputType.name),
          (_phone, 'Contact phone', TextInputType.phone),
          (_email, 'Email (optional)', TextInputType.emailAddress),
          (_location, 'Location or address', TextInputType.streetAddress),
        ]) ...[
          TextField(
            controller: field.$1,
            keyboardType: field.$3,
            decoration: InputDecoration(
              labelText: field.$2,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          initialValue: _schedule,
          decoration: const InputDecoration(
            labelText: 'Requested service timing',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'ASAP', child: Text('As soon as possible')),
            DropdownMenuItem(
              value: 'SCHEDULED',
              child: Text('Schedule for tomorrow at 09:00'),
            ),
          ],
          onChanged: (value) => _schedule = value!,
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<EligibleProvider>>(
          future: _providers,
          builder: (context, snapshot) => DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Assign approved Provider (optional)',
              border: OutlineInputBorder(),
            ),
            items: (snapshot.data ?? const <EligibleProvider>[])
                .map(
                  (provider) => DropdownMenuItem(
                    value: provider.userId,
                    child: Text(provider.companyName),
                  ),
                )
                .toList(),
            onChanged: (value) => _providerId = value,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Agreed whole-number price (UGX, optional)',
            border: OutlineInputBorder(),
          ),
        ),
        if (_message case final message?) ...[
          const SizedBox(height: 12),
          WeyonjeAlert(
            title: 'Request not saved',
            message: message,
            error: true,
          ),
        ],
        const SizedBox(height: 20),
        WeyonjeButton(
          label: 'Create manual request',
          loading: _busy,
          onPressed: _create,
        ),
        const SizedBox(height: 28),
        Text(
          'Recent manual requests',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        FutureBuilder<List<ServiceRequestSummary>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator();
            }
            if (snapshot.hasError) {
              return WorkflowErrorView(
                error: snapshot.error!,
                onRetry: () => setState(_reload),
              );
            }
            if (snapshot.requireData.isEmpty) {
              return const Text('No manual requests yet.');
            }
            return Column(
              children: snapshot.requireData
                  .map(
                    (request) =>
                        RequestSummaryCard(request: request, onTap: () {}),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );

  Future<void> _findClient() async {
    final clients = await ref
        .read(workflowRepositoryProvider)
        .callCentreClients(_name.text);
    if (!mounted) return;
    final selected = await showDialog<CallCentreClient>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select existing Client'),
        children: clients.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No matching Client was found.'),
                ),
              ]
            : clients
                  .map(
                    (client) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, client),
                      child: Text('${client.name}\n${client.phoneNumber}'),
                    ),
                  )
                  .toList(),
      ),
    );
    if (selected != null) {
      setState(() {
        _clientId = selected.userId;
        _name.text = selected.name;
        _phone.text = selected.phoneNumber;
        _email.text = selected.email ?? '';
      });
    }
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _location.text.trim().isEmpty) {
      setState(
        () => _message = 'Enter the Client name, contact phone, and location.',
      );
      return;
    }
    final price = _price.text.trim().isEmpty
        ? null
        : int.tryParse(_price.text.trim());
    if (_price.text.trim().isNotEmpty && (price == null || price < 0)) {
      setState(() => _message = 'Enter a non-negative whole-number UGX price.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      var request = await ref
          .read(workflowRepositoryProvider)
          .createCallCentreRequest({
            if (_clientId != null) 'clientUserId': _clientId,
            'clientName': _name.text.trim(),
            'clientPhone': _phone.text.trim(),
            if (_email.text.trim().isNotEmpty)
              'clientEmail': _email.text.trim(),
            'locationKind': 'TEXT',
            'locationText': _location.text.trim(),
            'scheduleMode': _schedule,
            if (_schedule == 'SCHEDULED')
              'requestedServiceAt': DateTime.now()
                  .add(const Duration(days: 1))
                  .copyWith(hour: 9, minute: 0)
                  .toUtc()
                  .toIso8601String(),
          });
      if (_providerId != null) {
        request = await ref
            .read(workflowRepositoryProvider)
            .assignCallCentreRequest(request.id, _providerId!, priceUgx: price);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request ${request.reference} saved.')),
        );
        setState(_reload);
      }
    } catch (error) {
      _message = error.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class DisposalSiteAdministrationScreen extends ConsumerStatefulWidget {
  const DisposalSiteAdministrationScreen({super.key});
  @override
  ConsumerState<DisposalSiteAdministrationScreen> createState() =>
      _DisposalSiteAdministrationScreenState();
}

class _DisposalSiteAdministrationScreenState
    extends ConsumerState<DisposalSiteAdministrationScreen> {
  late Future<List<DisposalSite>> _load;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      _load = ref.read(workflowRepositoryProvider).disposalSites();

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Disposal-site administration',
    showBack: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Only KCCA may approve, edit, activate, or deactivate disposal sites.',
        ),
        const SizedBox(height: 16),
        WeyonjeButton(label: 'Create disposal site', onPressed: () => _edit()),
        const SizedBox(height: 16),
        FutureBuilder<List<DisposalSite>>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator();
            }
            if (snapshot.hasError) {
              return WorkflowErrorView(
                error: snapshot.error!,
                onRetry: () => setState(_reload),
              );
            }
            if (snapshot.requireData.isEmpty) {
              return const Text('No disposal sites have been recorded.');
            }
            return Column(
              children: snapshot.requireData
                  .map(
                    (site) => Card(
                      child: ListTile(
                        title: Text(site.name),
                        subtitle: Text(
                          '${site.address}\n${site.latitude}, ${site.longitude}\n${site.active ? 'Active' : 'Inactive'}',
                        ),
                        onTap: () => _edit(site),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );

  Future<void> _edit([DisposalSite? site]) async {
    final name = TextEditingController(text: site?.name);
    final address = TextEditingController(text: site?.address);
    final latitude = TextEditingController(text: site?.latitude?.toString());
    final longitude = TextEditingController(text: site?.longitude?.toString());
    var active = site?.active ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            site == null ? 'Create disposal site' : 'Edit disposal site',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in [
                  (name, 'Site name'),
                  (address, 'Address'),
                  (latitude, 'Latitude'),
                  (longitude, 'Longitude'),
                ]) ...[
                  TextField(
                    controller: field.$1,
                    decoration: InputDecoration(labelText: field.$2),
                  ),
                  const SizedBox(height: 8),
                ],
                SwitchListTile(
                  value: active,
                  onChanged: (value) => setLocal(() => active = value),
                  title: const Text('Active and assignable'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final lat = double.tryParse(latitude.text);
      final lng = double.tryParse(longitude.text);
      if (name.text.trim().isNotEmpty &&
          address.text.trim().isNotEmpty &&
          lat != null &&
          lng != null) {
        await ref.read(workflowRepositoryProvider).saveDisposalSite({
          'id': site?.id ?? const Uuid().v4(),
          'name': name.text.trim(),
          'address': address.text.trim(),
          'latitude': lat,
          'longitude': lng,
          'active': active,
        });
        if (mounted) setState(_reload);
      }
    }
    name.dispose();
    address.dispose();
    latitude.dispose();
    longitude.dispose();
  }
}
