import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';

enum RegistrationAccountType { client, serviceProvider }

class ChooseAccountTypeScreen extends StatefulWidget {
  const ChooseAccountTypeScreen({super.key});

  @override
  State<ChooseAccountTypeScreen> createState() =>
      _ChooseAccountTypeScreenState();
}

class _ChooseAccountTypeScreenState extends State<ChooseAccountTypeScreen> {
  RegistrationAccountType? _selection;
  bool _showError = false;
  bool _navigating = false;

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Choose Account Type',
    showBack: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Account type, required, single selection',
          value: switch (_selection) {
            RegistrationAccountType.client => 'Client selected',
            RegistrationAccountType.serviceProvider =>
              'Service Provider selected',
            null => 'No account type selected',
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FRadio(
                key: const Key('account-client'),
                value: _selection == RegistrationAccountType.client,
                semanticsLabel: 'Client. Request Waste-Collection Services.',
                label: const Text('Client'),
                description: const Text('Request Waste-Collection Services.'),
                onChange: (_) => _select(RegistrationAccountType.client),
              ),
              const SizedBox(height: 16),
              FRadio(
                key: const Key('account-provider'),
                value: _selection == RegistrationAccountType.serviceProvider,
                semanticsLabel:
                    'Service Provider. Receive and Handle Service Requests',
                label: const Text('Service Provider'),
                description: const Text('Receive and Handle Service Requests'),
                onChange: (_) =>
                    _select(RegistrationAccountType.serviceProvider),
              ),
            ],
          ),
        ),
        if (_showError) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: const WeyonjeAlert(
              title: 'Account Type Required',
              message: 'Select an account type to continue.',
              error: true,
            ),
          ),
        ],
        const SizedBox(height: 32),
        WeyonjeButton(
          key: const Key('account-continue'),
          label: 'Continue',
          onPressed: _navigating ? null : _continue,
        ),
      ],
    ),
  );

  void _select(RegistrationAccountType value) => setState(() {
    _selection = value;
    _showError = false;
  });

  void _continue() {
    if (_navigating) return;
    final selection = _selection;
    if (selection == null) {
      setState(() => _showError = true);
      return;
    }
    setState(() => _navigating = true);
    context
        .push(
          selection == RegistrationAccountType.client
              ? '/register/client'
              : '/register/service-provider',
        )
        .whenComplete(() {
          if (mounted) setState(() => _navigating = false);
        });
  }
}
