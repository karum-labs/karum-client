import 'package:flutter/material.dart';

import 'src/api/gateway_client.dart';
import 'src/api/health_status.dart';
import 'src/app/app_scope.dart';
import 'src/app/routes.dart';
import 'src/screens/door_pitch_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/judge_entry_screen.dart';
import 'src/screens/landing_screen.dart';
import 'src/screens/not_found_screen.dart';
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
  const KarumApp({super.key, this.client, this.initialRoute});

  /// Injectable client for widget tests.
  final GatewayClient? client;

  /// Optional initial route for tests.
  final String? initialRoute;

  @override
  State<KarumApp> createState() => _KarumAppState();
}

class _KarumAppState extends State<KarumApp> {
  late final GatewayClient _client;
  late final bool _ownsClient;
  HealthStatus? _health;
  Object? _healthError;
  bool _healthLoading = true;

  /// The gateway exposes no hackathon flag yet. The client env var keeps the
  /// judge entry route out of a normal deployment without introducing a login
  /// wall into the demo path. See PLAN.md §28.
  static const bool _hackathonMode = bool.fromEnvironment(
    'HACKATHON_MODE',
    defaultValue: true,
  );

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.client == null;
    _client = widget.client ?? GatewayClient();
    _refreshHealth();
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
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
        hackathonMode: _hackathonMode,
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
        JudgeEntryScreen(hackathonMode: _hackathonMode),
        settings.name ?? '/login',
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
