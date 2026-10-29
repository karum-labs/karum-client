import 'package:flutter/material.dart';

import 'src/api/auth_models.dart';
import 'src/api/gateway_client.dart';
import 'src/api/health_status.dart';
import 'src/app/app_scope.dart';
import 'src/app/routes.dart';
import 'src/auth/session_storage.dart';
import 'src/config/app_flags.dart';
import 'src/data/presets.dart';
import 'src/screens/account_screen.dart';
import 'src/screens/door_pitch_screen.dart';
import 'src/screens/history_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/judge_entry_screen.dart';
import 'src/screens/landing_screen.dart';
import 'src/screens/not_found_screen.dart';
import 'src/screens/register_screen.dart';
import 'src/screens/workspace_screen.dart';
import 'src/theme/app_theme.dart';

/// Karum client entrypoint.
///
/// The app targets Flutter web for judging and keeps the same screens on
/// desktop. The gateway base URL comes from `--dart-define=GATEWAY_URL=...` —
/// see [AppConfig] — so switching between local Compose and production is a
/// build flag, not a code change.
void main() {
  runApp(const KarumApp());
}

/// Root widget: owns the gateway client, health snapshot, theme, and routes.
class KarumApp extends StatefulWidget {
  const KarumApp({
    super.key,
    this.client,
    this.initialRoute,
    this.showJudgesBanner,
  });

  /// Injectable client for widget tests.
  final GatewayClient? client;

  /// Optional initial route for tests.
  final String? initialRoute;

  /// Test override for the login-screen judges banner.
  ///
  /// Null uses [AppFlags.showJudgesBanner].
  final bool? showJudgesBanner;

  @override
  State<KarumApp> createState() => _KarumAppState();
}

class _KarumAppState extends State<KarumApp> {
  late final GatewayClient _client;
  late final bool _ownsClient;
  HealthStatus? _health;
  Object? _healthError;
  bool _healthLoading = true;
  PresetCatalog? _presets;
  Object? _presetsError;
  bool _presetsLoading = true;
  AuthSession? _session;
  bool _authResolving = true;

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.client == null;
    _client = widget.client ?? GatewayClient();
    _bootstrap();
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _restoreSession();
    // Health and the preset catalogue are independent reads; fetching them
    // together halves the time to the first paint of the landing page.
    await Future.wait([_refreshHealth(), _refreshPresets()]);
  }

  /// Restores a saved browser session and validates it with `/auth/me`.
  Future<void> _restoreSession() async {
    final token = readSessionToken();
    if (token == null) {
      if (mounted) setState(() => _authResolving = false);
      return;
    }
    _client.setToken(token);
    try {
      final account = await _client.fetchMe();
      if (!mounted) return;
      setState(() {
        _session = AuthSession(token: token, account: account);
        _authResolving = false;
      });
    } catch (_) {
      _client.setToken(null);
      writeSessionToken(null);
      if (mounted) setState(() => _authResolving = false);
    }
  }

  Future<void> _refreshHealth() async {
    if (mounted) {
      setState(() => _healthLoading = true);
    }
    try {
      final health = await _client.fetchHealth();
      if (!mounted) return;
      setState(() {
        _health = health;
        _healthError = null;
        _healthLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _healthError = error;
        _healthLoading = false;
      });
    }
  }

  /// Fetches the locked previous-run catalogue. Unlike health, a failure here does
  /// not take the whole app offline — the landing page's previous-run section
  /// shows its own retry state and every other screen works without it.
  Future<void> _refreshPresets() async {
    if (mounted) {
      setState(() => _presetsLoading = true);
    }
    try {
      final presets = await _client.fetchPresets();
      if (!mounted) return;
      setState(() {
        _presets = presets;
        _presetsError = null;
        _presetsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _presetsError = error;
        _presetsLoading = false;
      });
    }
  }

  Future<void> _signIn(String email, String password) async {
    final session = await _client.login(email: email, password: password);
    if (!mounted) return;
    _setSession(session);
  }

  Future<void> _judgeSignIn() async {
    final session = await _client.judgeLogin();
    if (!mounted) return;
    _setSession(session);
  }

  Future<void> _register({
    required String email,
    required String password,
  }) async {
    final session = await _client.register(email: email, password: password);
    if (!mounted) return;
    _setSession(session);
  }

  Future<void> _signOut() async {
    try {
      await _client.logout();
    } catch (_) {
      // A rejected or offline logout still clears the local session.
    } finally {
      _client.setToken(null);
      writeSessionToken(null);
      if (mounted) setState(() => _session = null);
    }
  }

  void _setSession(AuthSession session) {
    _client.setToken(session.token);
    writeSessionToken(session.token);
    setState(() => _session = session);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karum',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // The guide publishes a light and a dark palette and switches on
      // `prefers-color-scheme`; ThemeMode.system is that behaviour.
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: widget.initialRoute,
      onGenerateRoute: _route,
      onUnknownRoute: (settings) =>
          _page(const NotFoundScreen(), settings.name ?? '/missing'),
      builder: (context, child) => AppScope(
        client: _client,
        health: _health,
        healthLoading: _healthLoading,
        healthError: _healthError,
        refreshHealth: _refreshHealth,
        hackathonMode: _health?.hackathonMode ?? false,
        presets: _presets,
        presetsLoading: _presetsLoading,
        presetsError: _presetsError,
        refreshPresets: _refreshPresets,
        session: _session,
        authResolving: _authResolving,
        signIn: _signIn,
        judgeSignIn: _judgeSignIn,
        register: _register,
        signOut: _signOut,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  Route<dynamic> _route(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');
    final segments = uri.pathSegments;
    final args = settings.arguments;

    if (segments.isEmpty || (segments.length == 1 && segments[0] == 'home')) {
      return _page(const LandingScreen(), settings.name ?? '/');
    }
    if (segments.length == 1 && segments[0] == 'status') {
      return _page(HomeScreen(client: _client), settings.name ?? '/status');
    }
    if (segments.length == 1 && segments[0] == 'login') {
      return _page(
        JudgeEntryScreen(showJudgesBanner: widget.showJudgesBanner),
        settings.name ?? '/login',
      );
    }
    if (segments.length == 1 && segments[0] == 'register') {
      return _page(const RegisterScreen(), settings.name ?? '/register');
    }
    if (segments.length == 1 && segments[0] == 'account') {
      return _page(const AccountScreen(), settings.name ?? '/account');
    }
    if (segments.length == 2 &&
        segments[0] == 'account' &&
        segments[1] == 'history') {
      return _page(
        const CampaignHistoryScreen(),
        settings.name ?? '/account/history',
      );
    }

    // /scout/:jobId/doors/:doorId
    if (segments.length == 4 &&
        segments[0] == 'scout' &&
        segments[2] == 'doors') {
      return _page(
        DoorPitchScreen(jobId: segments[1], doorId: segments[3]),
        settings.name ?? '/scout',
      );
    }

    // /scout/:jobId
    if (segments.length == 2 && segments[0] == 'scout') {
      final showCoach = args is WorkspaceArgs && args.showCoach;
      return _page(
        ScoutWorkspaceScreen(jobId: segments[1], showCoach: showCoach),
        settings.name ?? '/scout',
      );
    }

    // /campaigns/:campaignId
    if (segments.length == 2 && segments[0] == 'campaigns') {
      return _page(
        ScoutWorkspaceScreen(campaignId: segments[1]),
        settings.name ?? '/campaigns',
      );
    }

    return _page(
      NotFoundScreen(path: settings.name ?? '/'),
      settings.name ?? '/not-found',
    );
  }

  MaterialPageRoute<void> _page(Widget child, String name) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => child,
    );
  }
}
