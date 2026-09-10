import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/registration_models.dart';
import '../../../core/auth/sms_retriever.dart';
import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_otp_field.dart';
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
  final _code = FOtpController(
    value: const TextEditingValue(
      selection: TextSelection.collapsed(offset: 0),
    ),
  );
  late PhoneChallenge _challenge;
  late SmsRetrieval _retrieval;
  late int _retrievalGeneration;
  late PhoneVerificationController _controller;
  late final _controllerProvider = phoneVerificationControllerProvider(
    widget.arguments.challenge.id,
  );
  Timer? _timer;
  bool _replacing = false;
  String? _lastText;

  PhoneVerificationArguments get _arguments => PhoneVerificationArguments(
    challenge: _challenge,
    purpose: widget.arguments.purpose,
  );
  bool get _canResend =>
      !DateTime.now().toUtc().isBefore(_challenge.resendAvailableAt);
  bool get _expired => !DateTime.now().toUtc().isBefore(_challenge.expiresAt);

  @override
  void initState() {
    super.initState();
    _challenge = widget.arguments.challenge;
    _retrieval = ref.read(smsRetrievalProvider);
    _retrievalGeneration = _retrieval.generation;
    _controller = ref.read(_controllerProvider.notifier);
    _retrieval.addListener(_received);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _received();
      _changed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _retrieval.removeListener(_received);
    _controller.abandon();
    unawaited(_retrieval.stopIfCurrent(_retrievalGeneration));
    _code.dispose();
    super.dispose();
  }

  void _received() {
    if (!mounted || _replacing) return;
    final state = ref.read(_controllerProvider);
    if (state.inProgress || state.resending) return;
    final candidate = _retrieval.takeCandidate(_challenge.id);
    if (candidate == null) return;
    _fill(candidate.code);
    _changed();
  }

  void _fill(String code) {
    _code.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
  }

  void _changed() {
    if (_replacing || !mounted) return;
    if (_challenge.deliveryStatus == PhoneCodeDeliveryStatus.failed) return;
    if (_lastText == _code.text) return;
    _lastText = _code.text;
    final controller = ref.read(_controllerProvider.notifier);
    controller.edited();
    if (_code.text.length == 6) {
      unawaited(controller.verify(_arguments, _code.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_controllerProvider);
    final failed = _challenge.deliveryStatus == PhoneCodeDeliveryStatus.failed;
    final verified = state.phase == VerificationPhase.success;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _controller.abandon();
          unawaited(_retrieval.stopIfCurrent(_retrievalGeneration));
        }
      },
      child: WeyonjePage(
        title: 'Verify Phone Number',
        showBack: true,
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Verify ${_challenge.maskedPhone}.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                failed
                    ? 'SMS acceptance could not be confirmed. Your information was kept. Wait before requesting another code to continue; a delayed SMS may still arrive.'
                    : 'A code was submitted for SMS delivery. Enter it below when it arrives.',
              ),
              const SizedBox(height: 24),
              WeyonjeOtpField(
                controller: _code,
                onChanged: _changed,
                enabled: !failed && !state.inProgress && !state.resending,
                invalid: state.phase == VerificationPhase.invalid,
                verified: verified,
              ),
              if (state.message case final message?) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: WeyonjeAlert(
                    title: verified
                        ? 'Phone Verified'
                        : state.phase == VerificationPhase.checking
                        ? 'Checking Code'
                        : 'Verification Not Completed',
                    message: message,
                    error:
                        !verified && state.phase != VerificationPhase.checking,
                  ),
                ),
              ],
              if (_expired && !verified) ...[
                const SizedBox(height: 12),
                const Text(
                  'The code expiry time has passed. Request another code.',
                ),
              ],
              if (state.phase == VerificationPhase.network) ...[
                const SizedBox(height: 20),
                WeyonjeButton(
                  key: const Key('verify-phone'),
                  label: 'Retry Verification',
                  onPressed: () => ref
                      .read(_controllerProvider.notifier)
                      .verify(_arguments, _code.text, retry: true),
                ),
              ],
              const SizedBox(height: 24),
              WeyonjeButton(
                key: const Key('resend-phone-code'),
                label: _canResend
                    ? 'Send Another Code'
                    : 'Please Wait to Resend',
                kind: WeyonjeButtonKind.outline,
                loading: state.resending,
                onPressed: _canResend && !state.inProgress && !state.resending
                    ? _resend
                    : null,
              ),
              if (!state.inProgress) ...[
                const SizedBox(height: 12),
                WeyonjeButton(
                  label: 'Return to Sign In',
                  kind: WeyonjeButtonKind.outline,
                  onPressed: () => context.go(
                    widget.arguments.purpose ==
                            PhoneVerificationPurpose.clientSignIn
                        ? '/sign-in/client'
                        : '/welcome',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resend() async {
    _replacing = true;
    _lastText = null;
    _code.clear();
    final request = ref.read(_controllerProvider.notifier).resend(_arguments);
    _retrievalGeneration = _retrieval.generation;
    final challenge = await request;
    if (!mounted) return;
    _replacing = false;
    if (challenge == null) return;
    setState(() => _challenge = challenge);
    _received();
    _changed();
  }
}
