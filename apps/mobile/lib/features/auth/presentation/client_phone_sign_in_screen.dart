import 'dart:async';
import 'package:forui/forui.dart';
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
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientCodeControllerProvider);
    return WeyonjePage(
      title: 'Client Sign In',
      showBack: true,
      child: Material(
        color: Colors.transparent,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FTextFormField(
                key: const Key('client-sign-in-phone'),
                control: FTextFieldControl.managed(controller: _phone),
                enabled: !state.inProgress,
                autofocus: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                label: Text('Phone Number'),
                hint: 'e.g. 0700 000000',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your phone number.'
                    : null,
                onSubmit: (_) => _submit(state.inProgress),
              ),
              if (state.message case final message?) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: WeyonjeAlert(
                    title: state.rateLimited
                        ? 'Try Again Later'
                        : 'Code Not Sent',
                    message: message,
                    error: true,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              WeyonjeButton(
                key: const Key('request-client-code'),
                label: 'Send Sign-In Code',
                loading: state.inProgress,
                onPressed: state.waiting
                    ? null
                    : () => _submit(state.inProgress),
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
    if (!mounted) return;
    if (ref.read(clientCodeControllerProvider).registrationRequired) {
      context.push(
        '/register/client',
        extra: ClientRegistrationArguments(_phone.text),
      );
      return;
    }
    if (challenge == null) return;
    context.push(
      '/verify-phone',
      extra: PhoneVerificationArguments(
        challenge: challenge,
        purpose: PhoneVerificationPurpose.clientSignIn,
      ),
    );
  }
}
