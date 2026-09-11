import '../../../ui/weyonje_select.dart';
import 'package:forui/forui.dart';
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
      title: 'Service Provider Registration',
      titleStyle: context.theme.typography.display.sm.copyWith(
        fontWeight: FontWeight.w600,
      ),
      showBack: true,
      child: Material(
        color: Colors.transparent,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'KCCA Approval Required',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.theme.colors.error,
                ),
              ),
              const SizedBox(height: 24),
              _requiredField(
                key: const Key('provider-ess-license'),
                controller: _essLicense,
                label: 'ESS Licence Number (Required)',
              ),
              const SizedBox(height: 20),
              _requiredField(
                key: const Key('provider-company-name'),
                controller: _companyName,
                label: 'Company Name (Required)',
              ),
              const SizedBox(height: 20),
              _requiredField(
                key: const Key('provider-phone'),
                controller: _phone,
                label: 'Phone Number (Required)',
                hint: 'e.g. 0700 000000',
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              const SizedBox(height: 20),
              FTextFormField(
                key: const Key('provider-email'),
                control: FTextFieldControl.managed(controller: _email),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                label: Text('Email Address (Required)'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return email.isEmpty || !email.contains('@')
                      ? 'Enter a valid email address.'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              _requiredField(
                key: const Key('provider-work-address'),
                controller: _workAddress,
                label: 'Work Address / Location (Required)',
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              WeyonjeSelect<ServiceProviderType>(
                key: const Key('provider-type'),
                initialValue: _providerType,
                label: Text('Service Provider Type (Required)'),
                items: const [
                  (value: ServiceProviderType.gulper, label: 'Gulper'),
                  (value: ServiceProviderType.emptier, label: 'Emptier'),
                ],
                onChanged: (value) => setState(() => _providerType = value),
                validator: (value) =>
                    value == null ? 'Select a Service Provider type.' : null,
              ),
              const SizedBox(height: 20),
              _requiredField(
                key: const Key('provider-contact-name'),
                controller: _contactName,
                label: 'Contact Person Name (Required)',
              ),
              const SizedBox(height: 20),
              _requiredField(
                key: const Key('provider-contact-phone'),
                controller: _contactPhone,
                label: 'Contact Person Phone Number (Required)',
                keyboardType: TextInputType.phone,
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
                key: const Key('submit-provider-registration'),
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

  Widget _requiredField({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    int maxLines = 1,
  }) => FTextFormField(
    key: key,
    control: FTextFieldControl.managed(controller: controller),
    keyboardType: keyboardType,
    autofillHints: autofillHints,
    maxLines: maxLines,
    label: Text(label),
    hint: hint,
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
