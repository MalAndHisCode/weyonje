import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/registration_models.dart';
import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/registration_controller.dart';

class ClientRegistrationScreen extends ConsumerStatefulWidget {
  const ClientRegistrationScreen({super.key});

  @override
  ConsumerState<ClientRegistrationScreen> createState() =>
      _ClientRegistrationScreenState();
}

class _ClientRegistrationScreenState
    extends ConsumerState<ClientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _organizationName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  ClientType? _clientType;
  bool _showTypeError = false;

  bool get _individual => _clientType == ClientType.individual;
  bool get _organization => _clientType == ClientType.organization;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _organizationName,
      _phone,
      _email,
      _contactName,
      _contactPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationControllerProvider);
    return WeyonjePage(
      title: 'Client Registration',
      showBack: true,
      child: Material(
        color: Colors.transparent,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create a Client account to request waste-collection services. Required fields are marked in their labels.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Semantics(
                container: true,
                label: 'Client type, required',
                value: switch (_clientType) {
                  ClientType.individual => 'Individual selected',
                  ClientType.organization => 'Company or organization selected',
                  null => 'No selection',
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Client type (required)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    FRadio(
                      key: const Key('client-type-individual'),
                      value: _individual,
                      semanticsLabel: 'Individual Client',
                      label: const Text('Individual'),
                      onChange: (_) => _selectType(ClientType.individual),
                    ),
                    const SizedBox(height: 8),
                    FRadio(
                      key: const Key('client-type-organization'),
                      value: _organization,
                      semanticsLabel: 'Company or Organization Client',
                      label: const Text('Company / Organization'),
                      onChange: (_) => _selectType(ClientType.organization),
                    ),
                    if (_showTypeError) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Select a Client type.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_individual) ...[
                const SizedBox(height: 20),
                _textField(
                  key: const Key('client-first-name'),
                  controller: _firstName,
                  label: 'First name (required)',
                ),
                const SizedBox(height: 20),
                _textField(
                  key: const Key('client-last-name'),
                  controller: _lastName,
                  label: 'Last name (required)',
                ),
              ],
              if (_organization) ...[
                const SizedBox(height: 20),
                _textField(
                  key: const Key('client-organization-name'),
                  controller: _organizationName,
                  label: 'Company / Organization name (required)',
                ),
                const SizedBox(height: 20),
                _textField(
                  key: const Key('client-contact-name'),
                  controller: _contactName,
                  label: 'Contact person name (required)',
                ),
                const SizedBox(height: 20),
                _textField(
                  key: const Key('client-contact-phone'),
                  controller: _contactPhone,
                  label: 'Contact person phone number (required)',
                  keyboardType: TextInputType.phone,
                ),
              ],
              const SizedBox(height: 20),
              _textField(
                key: const Key('client-phone'),
                controller: _phone,
                label: 'Phone number (required)',
                hint: 'e.g. 0700 000000',
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              const SizedBox(height: 20),
              FTextFormField(
                key: const Key('client-email'),
                control: FTextFieldControl.managed(controller: _email),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                label: Text('Email address (optional)'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return email.isNotEmpty && !email.contains('@')
                      ? 'Enter a valid email address or leave this field blank.'
                      : null;
                },
              ),
              if (state.message case final message?) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: WeyonjeAlert(
                    title: state.rateLimited
                        ? 'Try Again Later'
                        : 'Registration Not Submitted',
                    message: message,
                    error: true,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              WeyonjeButton(
                key: const Key('submit-client-registration'),
                label: 'Submit Registration',
                loading: state.inProgress,
                onPressed: () => _submit(state.inProgress),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
  }) => FTextFormField(
    key: key,
    control: FTextFieldControl.managed(controller: controller),
    keyboardType: keyboardType,
    autofillHints: autofillHints,
    label: Text(label),
    hint: hint,
    validator: (value) => value == null || value.trim().isEmpty
        ? 'Complete this required field.'
        : null,
  );

  void _selectType(ClientType type) => setState(() {
    _clientType = type;
    _showTypeError = false;
  });

  Future<void> _submit(bool inProgress) async {
    if (inProgress) return;
    final typeValid = _clientType != null;
    setState(() => _showTypeError = !typeValid);
    if (!typeValid || !_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final challenge = await ref
        .read(registrationControllerProvider.notifier)
        .submitClient(
          ClientRegistrationRequest(
            clientType: _clientType!,
            phoneNumber: _phone.text,
            firstName: _individual ? _firstName.text : null,
            lastName: _individual ? _lastName.text : null,
            organizationName: _organization ? _organizationName.text : null,
            email: email.isEmpty ? null : email,
            contactPersonName: _organization ? _contactName.text : null,
            contactPersonPhone: _organization ? _contactPhone.text : null,
          ),
        );
    if (!mounted || challenge == null) return;
    context.push(
      '/verify-phone',
      extra: PhoneVerificationArguments(
        challenge: challenge,
        purpose: PhoneVerificationPurpose.registration,
      ),
    );
  }
}
