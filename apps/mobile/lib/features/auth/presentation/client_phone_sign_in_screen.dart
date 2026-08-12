import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/registration_models.dart';
import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/registration_controller.dart';

class ClientPhoneSignInScreen extends ConsumerStatefulWidget {
  const ClientPhoneSignInScreen({super.key});

  @override
  ConsumerState<ClientPhoneSignInScreen> createState() =>
      _ClientPhoneSignInScreenState();
}

class _ClientPhoneSignInScreenState
    extends ConsumerState<ClientPhoneSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientCodeControllerProvider);
    return WeyonjePage(
      title: 'Client sign in',
      showBack: true,
      child: Material(
        color: Colors.transparent,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the verified phone number for your Client account. We will send a six-digit sign-in code.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('client-sign-in-phone'),
                controller: _phone,
                enabled: !state.inProgress,
                autofocus: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: 'e.g. 0700 000000',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your phone number.'
                    : null,
                onFieldSubmitted: (_) => _submit(state.inProgress),
              ),
              if (state.message case final message?) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: WeyonjeAlert(
                    title: state.rateLimited
                        ? 'Try again later'
                        : 'Code not sent',
                    message: message,
                    error: true,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              WeyonjeButton(
                key: const Key('request-client-code'),
                label: 'Send sign-in code',
                loading: state.inProgress,
                onPressed: () => _submit(state.inProgress),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(bool inProgress) async {
    if (inProgress || !_formKey.currentState!.validate()) return;
    final challenge = await ref
        .read(clientCodeControllerProvider.notifier)
        .requestCode(_phone.text);
    if (!mounted || challenge == null) return;
    context.push(
      '/verify-phone',
      extra: PhoneVerificationArguments(
        challenge: challenge,
        purpose: PhoneVerificationPurpose.clientSignIn,
      ),
    );
  }
}
