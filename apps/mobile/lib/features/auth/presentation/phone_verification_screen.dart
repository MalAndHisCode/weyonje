import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/registration_models.dart';
import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/registration_controller.dart';

class PhoneVerificationScreen extends ConsumerStatefulWidget {
  const PhoneVerificationScreen({required this.arguments, super.key});

  final PhoneVerificationArguments arguments;

  @override
  ConsumerState<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState
    extends ConsumerState<PhoneVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  late PhoneChallenge _challenge;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _challenge = widget.arguments.challenge;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_canResend) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  bool get _canResend =>
      !DateTime.now().toUtc().isBefore(_challenge.resendAvailableAt);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneVerificationControllerProvider);
    final arguments = PhoneVerificationArguments(
      challenge: _challenge,
      purpose: widget.arguments.purpose,
    );
    return WeyonjePage(
      title: 'Verify phone number',
      showBack: true,
      child: Material(
        color: Colors.transparent,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the six-digit code sent to ${_challenge.maskedPhone}.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (_challenge.deliveryStatus ==
                  PhoneCodeDeliveryStatus.failed) ...[
                const SizedBox(height: 20),
                const WeyonjeAlert(
                  title: 'Code not sent',
                  message:
                      'The SMS provider did not accept the message. Your information was kept; request another code to retry.',
                  error: true,
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('verification-code'),
                controller: _code,
                enabled: !state.inProgress && !state.resending,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                  hintText: 'Six digits',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.length == 6
                    ? null
                    : 'Enter the six-digit verification code.',
                onFieldSubmitted: (_) => _verify(state.inProgress, arguments),
              ),
              if (state.message case final message?) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: WeyonjeAlert(
                    title: state.rateLimited
                        ? 'Try again later'
                        : 'Verification not completed',
                    message: message,
                    error: true,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              WeyonjeButton(
                key: const Key('verify-phone'),
                label:
                    widget.arguments.purpose ==
                        PhoneVerificationPurpose.clientSignIn
                    ? 'Sign in'
                    : 'Verify and create account',
                loading: state.inProgress,
                onPressed: () => _verify(state.inProgress, arguments),
              ),
              const SizedBox(height: 12),
              WeyonjeButton(
                key: const Key('resend-phone-code'),
                label: _canResend ? 'Send another code' : 'Code recently sent',
                kind: WeyonjeButtonKind.outline,
                loading: state.resending,
                onPressed: _canResend && !state.inProgress
                    ? () => _resend(arguments)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verify(bool inProgress, PhoneVerificationArguments arguments) {
    if (inProgress || !_formKey.currentState!.validate()) return;
    ref
        .read(phoneVerificationControllerProvider.notifier)
        .verify(arguments, _code.text);
  }

  Future<void> _resend(PhoneVerificationArguments arguments) async {
    final challenge = await ref
        .read(phoneVerificationControllerProvider.notifier)
        .resend(arguments);
    if (!mounted || challenge == null) return;
    _code.clear();
    setState(() => _challenge = challenge);
  }
}
