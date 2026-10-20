import 'package:flutter/material.dart';

import '../api/gateway_client.dart';
import '../app/app_scope.dart';
import '../theme/brand_tokens.dart';
import '../widgets/karum_chrome.dart';
import '../widgets/karum_logo.dart';

/// Email/password sign-in, plus the optional one-click hackathon judge path.
///
/// The public demo never redirects here. A session only attributes a scout to an
/// account; the preset and free-entry paths remain available anonymously.
class JudgeEntryScreen extends StatefulWidget {
  const JudgeEntryScreen({super.key, this.hackathonMode});

  /// Test override for the gateway-owned hackathon flag.
  final bool? hackathonMode;

  @override
  State<JudgeEntryScreen> createState() => _JudgeEntryScreenState();
}

class _JudgeEntryScreenState extends State<JudgeEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

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
      setState(() => _error = 'Judge access is unavailable in this build.');
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
          () => _error = 'Judge access failed. Use email and password instead.',
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
    final enabled = widget.hackathonMode ?? scope?.hackathonMode ?? false;
    final session = scope?.session;
    final resolving = scope?.authResolving ?? false;

    return Scaffold(
      body: Column(
        children: [
          const KarumHeader(),
          JudgeBanner(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(KarumSpacing.page),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const KarumLogo(height: 34),
                            const SizedBox(height: KarumSpacing.xl),
                            if (enabled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.brand.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    KarumRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  'HACKATHON MODE · JUDGE SIGN-IN',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: palette.brand,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                ),
                              ),
                            const SizedBox(height: KarumSpacing.lg),
                            Text(
                              session == null
                                  ? 'Sign in to Karum.'
                                  : 'You are signed in.',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: KarumSpacing.sm),
                            Text(
                              session == null
                                  ? 'A session attributes your scouts to your '
                                        'account. The sample campaigns and the '
                                        'free-entry builder stay available '
                                        'without signing in.'
                                  : 'The public demo is still open. Continue '
                                        'to the seed builder or sign out to '
                                        'return to an anonymous session.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: palette.mute),
                            ),
                            const SizedBox(height: KarumSpacing.xl),
                            if (resolving && session == null)
                              const Padding(
                                padding: EdgeInsets.only(
                                  bottom: KarumSpacing.lg,
                                ),
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
                              _buildForm(context, enabled: enabled),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool enabled}) {
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
          if (enabled) ...[
            const SizedBox(height: KarumSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _judgeSignIn,
                icon: const Icon(Icons.badge_outlined, size: 18),
                label: const Text('Use judge access'),
              ),
            ),
            const SizedBox(height: KarumSpacing.xs),
            Text(
              'Judge access is a credential-free session for the preseeded '
              'account. It is only enabled while the gateway reports '
              'HACKATHON_MODE=true.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.mute),
            ),
          ],
          const SizedBox(height: KarumSpacing.md),
          TextButton(
            onPressed: _busy ? null : _openDemo,
            child: const Text('Continue without signing in'),
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
