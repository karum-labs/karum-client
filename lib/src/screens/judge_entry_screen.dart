import 'package:flutter/material.dart';

import '../api/gateway_client.dart';
import '../app/app_scope.dart';
import '../config/app_flags.dart';
import '../theme/brand_tokens.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/karum_logo.dart';

/// Email/password sign-in, plus the optional hackathon judges banner.
///
/// The public demo never redirects here. A session only attributes a scout to
/// an account; the preset and free-entry paths remain available anonymously.
class JudgeEntryScreen extends StatefulWidget {
  const JudgeEntryScreen({super.key, this.showJudgesBanner});

  /// Test override for [AppFlags.showJudgesBanner].
  final bool? showJudgesBanner;

  @override
  State<JudgeEntryScreen> createState() => _JudgeEntryScreenState();
}

class _JudgeEntryScreenState extends State<JudgeEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _showBanner => widget.showJudgesBanner ?? AppFlags.showJudgesBanner;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final scope = AppScope.maybeOf(context);
    if (scope == null) {
      setState(() => _error = 'Sign-in is unavailable in this build.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await scope.signIn(_email.text.trim(), _password.text);
      if (mounted) _openDemo();
    } on GatewayException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Sign-in failed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _judgeSignIn() async {
    if (_busy) return;
    final scope = AppScope.maybeOf(context);
    if (scope == null) {
      setState(() => _error = 'Demo access is unavailable in this build.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await scope.judgeSignIn();
      if (mounted) _openDemo();
    } on GatewayException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Demo access failed. Use email and password instead.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final scope = AppScope.maybeOf(context);
    if (scope == null) return;
    setState(() => _busy = true);
    await scope.signOut();
    if (mounted) setState(() => _busy = false);
  }

  void _openDemo() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final scope = AppScope.maybeOf(context);
    final session = scope?.session;
    final resolving = scope?.authResolving ?? false;

    return AuthScaffold(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const KarumLogo(height: 34),
            if (session == null && _showBanner) ...[
              const SizedBox(height: KarumSpacing.xl),
              _JudgesBanner(busy: _busy, onOpen: _judgeSignIn),
            ],
            const SizedBox(height: KarumSpacing.xl),
            Text(
              session == null ? 'Welcome back' : 'You are signed in.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: KarumSpacing.sm),
            Text(
              session == null
                  ? 'Sign in with your email and password.'
                  : 'The public demo is still open. Continue to the seed '
                        'builder or sign out.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.mute),
            ),
            const SizedBox(height: KarumSpacing.xl),
            if (resolving && session == null)
              const Padding(
                padding: EdgeInsets.only(bottom: KarumSpacing.lg),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (session != null)
              _SignedInPanel(
                email: session.account.email,
                displayName: session.account.displayName,
                isJudge: session.account.isJudge,
                busy: _busy,
                onContinue: _openDemo,
                onSignOut: _signOut,
              )
            else
              _buildForm(context),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
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
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
            ),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Enter your password.'
                : null,
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
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded, size: 18),
              label: Text(_busy ? 'Signing in…' : 'Sign in'),
            ),
          ),
          const SizedBox(height: KarumSpacing.md),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'New here?',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: palette.mute),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pushNamed('/register'),
                child: const Text('Create an account'),
              ),
            ],
          ),
          TextButton(
            onPressed: _busy ? null : _openDemo,
            child: const Text('Continue without signing in'),
          ),
        ],
      ),
    );
  }
}

class _JudgesBanner extends StatelessWidget {
  const _JudgesBanner({required this.busy, required this.onOpen});

  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KarumSpacing.lg),
      decoration: BoxDecoration(
        color: palette.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KarumRadius.control),
        border: Border.all(color: palette.brand.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hackathon judges',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: KarumSpacing.xs),
          Text(
            'Skip creating an account. Open the pre-seeded demo, with the '
            'sample campaigns already attached.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: palette.mute),
          ),
          const SizedBox(height: KarumSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: busy ? null : onOpen,
              child: Text(busy ? 'Opening…' : 'Open demo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedInPanel extends StatelessWidget {
  const _SignedInPanel({
    required this.email,
    required this.displayName,
    required this.isJudge,
    required this.busy,
    required this.onContinue,
    required this.onSignOut,
  });

  final String email;
  final String displayName;
  final bool isJudge;
  final bool busy;
  final VoidCallback onContinue;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(KarumSpacing.lg),
          decoration: BoxDecoration(
            color: palette.brand.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(KarumRadius.control),
            border: Border.all(color: palette.brand.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isEmpty ? email : displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.mute),
              ),
              if (isJudge) ...[
                const SizedBox(height: KarumSpacing.sm),
                Text(
                  'Judge account',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KarumSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : onContinue,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Continue to the demo'),
          ),
        ),
        const SizedBox(height: KarumSpacing.sm),
        TextButton(
          onPressed: busy ? null : onSignOut,
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
