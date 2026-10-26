import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// Sign in / sign up / password reset. Shown in cloud mode whenever no
/// session is restored (spec 6.1).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { signIn, signUp, forgot }

class _AuthScreenState extends State<AuthScreen> {
  _Mode _mode = _Mode.signIn;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Sign-in (including confirming an email or following a reset link)
  /// completes asynchronously; hop home as soon as a session exists.
  void _onAuthChanged() {
    if (widget.auth.isSignedIn && mounted) {
      context.go('/');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final auth = widget.auth;
    String? result;
    switch (_mode) {
      case _Mode.signIn:
        result = await auth.signIn(_email.text.trim(), _password.text);
      case _Mode.signUp:
        result = await auth.signUp(_email.text.trim(), _password.text);
      case _Mode.forgot:
        result = await auth.sendPasswordReset(_email.text.trim());
        if (result == null) {
          _info = 'Reset email sent. Follow the link in it to choose a new '
              'password.';
        }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result;
    });
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required.';
    if (_mode == _Mode.signUp && value.length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final heading = switch (_mode) {
      _Mode.signIn => 'Welcome back',
      _Mode.signUp => 'Create your account',
      _Mode.forgot => 'Reset your password',
    };
    final actionLabel = switch (_mode) {
      _Mode.signIn => 'Sign in',
      _Mode.signUp => 'Create account',
      _Mode.forgot => 'Send reset email',
    };

    return Scaffold(
      backgroundColor: QfColors.lichen,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: QfColors.pith,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('QuestFlow',
                        style: QfTheme.display(30, color: QfColors.bistre)),
                    const SizedBox(height: 4),
                    Text(heading,
                        style: const TextStyle(color: QfColors.bistreSoft)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration:
                          const InputDecoration(labelText: 'Email'),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 14),
                    if (_mode != _Mode.forgot)
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                        validator: _validatePassword,
                        onFieldSubmitted: (_) => _busy ? null : _submit(),
                      ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: QfColors.madder, fontSize: 14)),
                      ),
                    if (_info != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_info!,
                            style: const TextStyle(
                                color: QfColors.moss, fontSize: 14)),
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: QfColors.pith),
                            )
                          : Text(actionLabel),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: [
                        if (_mode == _Mode.signIn) ...[
                          TextButton(
                            onPressed: () => setState(
                                () => _mode = _Mode.forgot),
                            child: const Text('Forgot password?'),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _mode = _Mode.signUp),
                            child: const Text('Create an account'),
                          ),
                        ] else
                          TextButton(
                            onPressed: () =>
                                setState(() => _mode = _Mode.signIn),
                            child: const Text('Back to sign in'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
