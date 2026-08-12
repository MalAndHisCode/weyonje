import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/registration_models.dart';
import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/registration_controller.dart';

class ServiceProviderRegistrationScreen extends ConsumerStatefulWidget {
  const ServiceProviderRegistrationScreen({super.key});

  @override
  ConsumerState<ServiceProviderRegistrationScreen> createState() =>
      _ServiceProviderRegistrationScreenState();
}

class _ServiceProviderRegistrationScreenState
    extends ConsumerState<ServiceProviderRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _essLicense = TextEditingController();
  final _companyName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _workAddress = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  ServiceProviderType? _providerType;

  @override
  void dispose() {
    for (final controller in [
      _essLicense,
      _companyName,
      _phone,
      _email,
      _password,
      _confirmPassword,
      _workAddress,
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
      title: 'Service Provider registration',
      showBack: true,
      child: Material(
        color: Colors.transparent,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WeyonjeAlert(
                title: 'KCCA approval required',
                message:
                    'Your phone number must be verified and KCCA must approve the account before you can receive service requests. A current ESS licence and other applicable operating requirements are required.',
              ),
              const SizedBox(height: 24),
              _requiredField(
                key: const Key('provider-ess-license'),
                controller: _essLicense,
                label: 'ESS licence number (required)',
              ),
              const SizedBox(height: 20),
              _requiredField(
                key: const Key('provider-company-name'),
                controller: _companyName,
                label: 'Company name (required)',
              ),
              const SizedBox(height: 20),
              _requiredField(
                key: const Key('provider-phone'),
                controller: _phone,
                label: 'Phone number (required)',
                hint: 'e.g. 0700 000000',
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('provider-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email address (required)',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return email.isEmpty || !email.contains('@')
                      ? 'Enter a valid email address.'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('provider-password'),
                controller: _password,
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Password (required)',
                  helperText: 'Use at least 12 characters.',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.length ?? 0) < 12
                    ? 'Password must be at least 12 characters.'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('provider-confirm-password'),
                controller: _confirmPassword,
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Confirm password (required)',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value != _password.text ? 'Passwords must match.' : null,
              ),
              const SizedBox(height: 20),
              _requiredField(
                key: const Key('provider-work-address'),
                controller: _workAddress,
                label: 'Work address / location (required)',
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<ServiceProviderType>(
                key: const Key('provider-type'),
                initialValue: _providerType,
                decoration: const InputDecoration(
                  labelText: 'Service Provider type (required)',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ServiceProviderType.gulper,
                    child: Text('Gulper'),
                  ),
                  DropdownMenuItem(
                    value: ServiceProviderType.emptier,
                    child: Text('Emptier'),
                  ),
                ],
                onChanged: (value) => setState(() => _providerType = value),
                validator: (value) =>
                    value == null ? 'Select a Service Provider type.' : null,
              ),
              const SizedBox(height: 20),
              _requiredField(
                key: const Key('provider-contact-name'),
                controller: _contactName,
                label: 'Contact person name (required)',
              ),
              const SizedBox(height: 20),
              _requiredField(
                key: const Key('provider-contact-phone'),
                controller: _contactPhone,
                label: 'Contact person phone number (required)',
                keyboardType: TextInputType.phone,
              ),
              if (state.message case final message?) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: WeyonjeAlert(
                    title: state.rateLimited
                        ? 'Try again later'
                        : 'Registration not submitted',
                    message: message,
                    error: true,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              WeyonjeButton(
                key: const Key('submit-provider-registration'),
                label: 'Submit registration',
                loading: state.inProgress,
                onPressed: () => _submit(state.inProgress),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requiredField({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    int maxLines = 1,
  }) => TextFormField(
    key: key,
    controller: controller,
    keyboardType: keyboardType,
    autofillHints: autofillHints,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: const OutlineInputBorder(),
    ),
    validator: (value) => value == null || value.trim().isEmpty
        ? 'Complete this required field.'
        : null,
  );

  Future<void> _submit(bool inProgress) async {
    if (inProgress || !_formKey.currentState!.validate()) return;
    final challenge = await ref
        .read(registrationControllerProvider.notifier)
        .submitServiceProvider(
          ServiceProviderRegistrationRequest(
            essLicenseNumber: _essLicense.text,
            companyName: _companyName.text,
            phoneNumber: _phone.text,
            email: _email.text,
            password: _password.text,
            workAddress: _workAddress.text,
            providerType: _providerType!,
            contactPersonName: _contactName.text,
            contactPersonPhone: _contactPhone.text,
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
