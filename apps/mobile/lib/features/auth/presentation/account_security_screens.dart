import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../navigation/app_router.dart';
import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../data/account_security_repository.dart';

class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key});
  @override
  ConsumerState<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState
    extends ConsumerState<PasswordRecoveryScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _method = 'PHONE';
  AccountChallenge? _challenge;
  bool _busy = false;
  bool _complete = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Recover your account',
    showBack: true,
    child: Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_complete) ...[
            const WeyonjeAlert(
              title: 'Password changed',
              message:
                  'Your other sessions were signed out. Use your new password to sign in.',
            ),
            const SizedBox(height: 24),
            WeyonjeButton(
              label: 'Return to sign in',
              onPressed: () => context.go(AppRoutes.signIn),
            ),
          ] else if (_challenge == null) ...[
            const Text(
              'For Service Provider and KCCA accounts. We return the same response whether or not an account exists.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Registered email address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: 'Receive code by',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'PHONE', child: Text('Phone (SMS)')),
                DropdownMenuItem(value: 'EMAIL', child: Text('Email')),
              ],
              onChanged: _busy ? null : (value) => _method = value!,
            ),
            const SizedBox(height: 24),
            WeyonjeButton(
              label: 'Request recovery code',
              loading: _busy,
              onPressed: _request,
            ),
          ] else ...[
            Text(
              'Enter the six-digit code. It expires at ${_challenge!.expiresAt}.',
            ),
            if (_challenge!.developmentCode case final code?) ...[
              const SizedBox(height: 12),
              WeyonjeAlert(
                title: 'Development fake delivery',
                message: 'No real message was sent. Test code: $code',
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Verification code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'Use at least 12 characters.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            WeyonjeButton(
              label: 'Change password',
              loading: _busy,
              onPressed: _finish,
            ),
            TextButton(
              onPressed: _busy ? null : _resend,
              child: const Text('Request a newer code'),
            ),
          ],
          if (_message case final message?) ...[
            const SizedBox(height: 16),
            WeyonjeAlert(
              title: 'Recovery not completed',
              message: message,
              error: true,
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _request() async {
    if (!_email.text.contains('@')) {
      setState(() => _message = 'Enter a valid email address.');
      return;
    }
    await _run(() async {
      _challenge = await ref
          .read(accountSecurityRepositoryProvider)
          .requestRecovery(_email.text, _method);
      if (_challenge!.developmentCode != null) {
        _code.text = _challenge!.developmentCode!;
      }
    });
  }

  Future<void> _resend() => _run(() async {
    _challenge = await ref
        .read(accountSecurityRepositoryProvider)
        .resendRecovery(_challenge!.id);
    _code.text = _challenge!.developmentCode ?? '';
  });

  Future<void> _finish() async {
    if (_code.text.length != 6 || _password.text.length < 12) {
      setState(
        () => _message = 'Enter the six-digit code and a valid password.',
      );
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _message = 'The passwords do not match.');
      return;
    }
    await _run(() async {
      await ref
          .read(accountSecurityRepositoryProvider)
          .completeRecovery(_challenge!.id, _code.text, _password.text);
      _complete = true;
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
    } catch (error) {
      _message = error.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({
    super.key,
    this.initialChallengeId,
    this.initialCode,
  });
  final String? initialChallengeId;
  final String? initialCode;
  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode,
  );
  String? _challengeId;
  bool _busy = false;
  bool _complete = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _challengeId = widget.initialChallengeId;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WeyonjePage(
    title: 'Verify email address',
    showBack: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_complete)
          const WeyonjeAlert(
            title: 'Email verified',
            message: 'Your registered email address is now verified.',
          )
        else ...[
          const Text(
            'Choose where to receive a time-limited verification code. This does not replace your Weyonje sign-in method.',
          ),
          if (_challengeId == null) ...[
            const SizedBox(height: 24),
            WeyonjeButton(
              label: 'Send code by email',
              loading: _busy,
              onPressed: () => _request('EMAIL'),
            ),
            const SizedBox(height: 12),
            WeyonjeButton(
              label: 'Send code by phone',
              kind: WeyonjeButtonKind.outline,
              loading: _busy,
              onPressed: () => _request('PHONE'),
            ),
          ] else ...[
            const SizedBox(height: 20),
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Verification code',
                border: OutlineInputBorder(),
              ),
            ),
            WeyonjeButton(
              label: 'Verify email',
              loading: _busy,
              onPressed: _verify,
            ),
            TextButton(
              onPressed: _busy ? null : _resend,
              child: const Text('Request a newer code'),
            ),
          ],
        ],
        if (_message case final message?) ...[
          const SizedBox(height: 16),
          WeyonjeAlert(
            title: 'Verification not completed',
            message: message,
            error: true,
          ),
        ],
      ],
    ),
  );

  Future<void> _request(String method) => _run(() async {
    final challenge = await ref
        .read(accountSecurityRepositoryProvider)
        .requestEmailVerification(method);
    _challengeId = challenge.id;
    _code.text = challenge.developmentCode ?? '';
  });

  Future<void> _resend() => _run(() async {
    final challenge = await ref
        .read(accountSecurityRepositoryProvider)
        .resendEmailVerification(_challengeId!);
    _challengeId = challenge.id;
    _code.text = challenge.developmentCode ?? '';
  });

  Future<void> _verify() => _run(() async {
    await ref
        .read(accountSecurityRepositoryProvider)
        .verifyEmail(_challengeId!, _code.text);
    _complete = true;
  });

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
    } catch (error) {
      _message = error.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
