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

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Choose account type',
    showBack: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose how you will use Weyonje.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        FRadio(
          key: const Key('account-client'),
          value: _selection == RegistrationAccountType.client,
          semanticsLabel: 'Client account',
          label: const Text('Client'),
          description: const Text('Request waste-collection services.'),
          onChange: (_) => _select(RegistrationAccountType.client),
        ),
        const SizedBox(height: 16),
        FRadio(
          key: const Key('account-provider'),
          value: _selection == RegistrationAccountType.serviceProvider,
          semanticsLabel: 'Service Provider account',
          label: const Text('Service Provider'),
          description: const Text(
            'Provide waste-collection services after KCCA approval.',
          ),
          onChange: (_) => _select(RegistrationAccountType.serviceProvider),
        ),
        if (_showError) ...[
          const SizedBox(height: 20),
          const WeyonjeAlert(
            title: 'Choose an account type',
            message: 'Select Client or Service Provider before continuing.',
            error: true,
          ),
        ],
        const SizedBox(height: 32),
        WeyonjeButton(
          key: const Key('account-continue'),
          label: 'Continue',
          onPressed: _continue,
        ),
      ],
    ),
  );

  void _select(RegistrationAccountType value) => setState(() {
    _selection = value;
    _showError = false;
  });

  void _continue() {
    final selection = _selection;
    if (selection == null) {
      setState(() => _showError = true);
      return;
    }
    context.push(
      selection == RegistrationAccountType.client
          ? '/register/client/unavailable'
          : '/register/service-provider/unavailable',
    );
  }
}
