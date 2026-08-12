import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/weyonje_alert.dart';
import '../../../ui/weyonje_button.dart';
import '../../../ui/weyonje_page.dart';
import '../application/sign_in_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

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
      title: 'Provider or KCCA sign in',
      showBack: true,
      child: Material(
        color: Colors.transparent,
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the email and password for your Service Provider or KCCA account.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: TextFormField(
                    key: const Key('sign-in-email'),
                    controller: _email,
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
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      hintText: 'Enter your email address',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty ||
                          email.length > 254 ||
                          !email.contains('@')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                ),
                const SizedBox(height: 20),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: TextFormField(
                    key: const Key('sign-in-password'),
                    controller: _password,
                    focusNode: _passwordFocus,
                    enabled: !state.inProgress,
                    obscureText: true,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password.'
                        : null,
                    onFieldSubmitted: (_) => _submit(state.inProgress),
                  ),
                ),
                if (state.message case final message?) ...[
                  const SizedBox(height: 24),
                  WeyonjeAlert(
                    title: state.rateLimited
                        ? 'Try again shortly'
                        : 'Sign-in not completed',
                    message: message,
                    error: true,
                  ),
                ],
                const SizedBox(height: 32),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(3),
                  child: WeyonjeButton(
                    key: const Key('submit-sign-in'),
                    label: 'Sign in',
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
