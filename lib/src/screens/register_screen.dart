import 'package:flutter/material.dart';

import '../api/gateway_client.dart';
import '../app/app_scope.dart';
import '../theme/brand_tokens.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/karum_logo.dart';

/// Creates an account from an email and password, then signs in.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final scope = AppScope.maybeOf(context);
    if (scope == null) {
      setState(() => _error = 'Registration is unavailable in this build.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await scope.register(email: _email.text.trim(), password: _password.text);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/account', (route) => false);
      }
    } on GatewayException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not create the account. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KarumLogo(height: 34),
              const SizedBox(height: KarumSpacing.xl),
              Text(
                'Create an account',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: KarumSpacing.sm),
              Text(
                'Email and password. The sample campaigns stay available without an account.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: palette.mute),
              ),
              const SizedBox(height: KarumSpacing.xl),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Enter your email.';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: KarumSpacing.md),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) {
                  if (_confirm.text.isNotEmpty) {
                    _formKey.currentState?.validate();
                  }
                },
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter a password.';
                  }
                  if (value.length < 8) return 'Use at least 8 characters.';
                  return null;
                },
              ),
              const SizedBox(height: KarumSpacing.md),
              TextFormField(
                controller: _confirm,
                enabled: !_busy,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                validator: (value) {
                  if (value != _password.text) return 'Passwords do not match.';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: KarumSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.avoid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: KarumSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Creating…' : 'Create account'),
                ),
              ),
              const SizedBox(height: KarumSpacing.sm),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pushNamed('/login'),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
