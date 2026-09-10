import 'package:forui/forui.dart';
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
    _applyDevelopmentCode();
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
      title: 'Verify Phone Number',
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
                  title: 'Code Not Sent',
                  message:
                      'The SMS provider did not accept the message. Your information was kept; request another code to retry.',
                  error: true,
                ),
              ],
              if (_challenge.developmentVerificationCode != null) ...[
                const SizedBox(height: 20),
                WeyonjeAlert(
                  title: 'Development SMS Mode',
                  message:
                      'No SMS was sent. Use test code ${_challenge.developmentVerificationCode}; it has been filled in below.',
                ),
              ],
              const SizedBox(height: 24),
              FTextFormField(
                key: const Key('verification-code'),
                control: FTextFieldControl.managed(controller: _code),
                enabled: !state.inProgress && !state.resending,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                label: Text('Verification code'),
                hint: 'Six digits',
                validator: (value) => value?.length == 6
                    ? null
                    : 'Enter the six-digit verification code.',
                onSubmit: (_) => _verify(state.inProgress, arguments),
              ),
              if (state.message case final message?) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: WeyonjeAlert(
                    title: state.rateLimited
                        ? 'Try Again Later'
                        : 'Verification Not Completed',
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
                    ? 'Sign In'
                    : 'Verify and Create Account',
                loading: state.inProgress,
                onPressed: () => _verify(state.inProgress, arguments),
              ),
              const SizedBox(height: 12),
              WeyonjeButton(
                key: const Key('resend-phone-code'),
                label: _canResend ? 'Send Another Code' : 'Code Recently Sent',
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
    setState(() {
      _challenge = challenge;
      _applyDevelopmentCode();
    });
  }

  void _applyDevelopmentCode() {
    _code.text = _challenge.developmentVerificationCode ?? '';
  }
}
