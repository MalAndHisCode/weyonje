import 'package:forui/forui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/sign_in_controller.dart';
import '../../../navigation/app_router.dart';
import 'package:go_router/go_router.dart';

/// Presentation only; the server-resolved actor determines access after sign-in.
enum SignInEntry { provider, kcca }

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({this.entry, super.key});

  final SignInEntry? entry;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signInControllerProvider);
    return WeyonjePage(
      title: switch (widget.entry) {
        SignInEntry.provider => 'Provider Sign In',
        SignInEntry.kcca => 'KCCA Sign In',
        null => 'Provider or KCCA Sign In',
      },
      showBack: true,
      child: Material(
        color: Colors.transparent,
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(switch (widget.entry) {
                  SignInEntry.provider =>
                    'Enter the email and password for your Service Provider account.',
                  SignInEntry.kcca =>
                    'Enter the email and password for your KCCA account.',
                  null =>
                    'Enter the email and password for your Service Provider or KCCA account.',
                }, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 24),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: FTextFormField(
                    key: const Key('sign-in-email'),
                    control: FTextFieldControl.managed(controller: _email),
                    enabled: !state.inProgress,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    autocorrect: false,
                    enableSuggestions: false,
                    label: Text('Email address'),
                    hint: 'Enter your email address',
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty ||
                          email.length > 254 ||
                          !email.contains('@')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                    onSubmit: (_) => _passwordFocus.requestFocus(),
                  ),
                ),
                const SizedBox(height: 20),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: FTextFormField(
                    key: const Key('sign-in-password'),
                    control: FTextFieldControl.managed(controller: _password),
                    focusNode: _passwordFocus,
                    enabled: !state.inProgress,
                    obscureText: true,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    autocorrect: false,
                    enableSuggestions: false,
                    label: Text('Password'),
                    hint: 'Enter your password',
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password.'
                        : null,
                    onSubmit: (_) => _submit(state.inProgress),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FButton(
                    variant: FButtonVariant.ghost,
                    onPress: state.inProgress
                        ? null
                        : () => context.push(AppRoutes.passwordRecovery),
                    child: Flexible(child: const Text('Forgot Password?')),
                  ),
                ),
                if (state.message case final message?) ...[
                  const SizedBox(height: 24),
                  WeyonjeAlert(
                    title: state.rateLimited
                        ? 'Try Again Shortly'
                        : 'Sign-In Not Completed',
                    message: message,
                    error: true,
                  ),
                ],
                const SizedBox(height: 32),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(3),
                  child: WeyonjeButton(
                    key: const Key('submit-sign-in'),
                    label: 'Sign In',
                    loading: state.inProgress,
                    onPressed: () => _submit(state.inProgress),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit(bool inProgress) {
    if (inProgress || !_formKey.currentState!.validate()) return;
    ref
        .read(signInControllerProvider.notifier)
        .signIn(_email.text, _password.text);
  }
}
