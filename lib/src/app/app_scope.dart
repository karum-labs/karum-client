import 'package:flutter/widgets.dart';

import '../api/auth_models.dart';
import '../api/gateway_client.dart';
import '../api/health_status.dart';

/// The gateway client, health snapshot, and judge session shared by every route.
///
/// Routes read this instead of constructing their own client, so a health retry,
/// a session restore, or an injected test client reaches the whole tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.client,
    required this.health,
    required this.healthLoading,
    required this.healthError,
    required this.refreshHealth,
    required this.hackathonMode,
    required this.session,
    required this.authResolving,
    required this.signIn,
    required this.judgeSignIn,
    required this.signOut,
    required super.child,
  });

  /// The one gateway client for the app.
  final GatewayClient client;

  /// The latest health payload, or null while the first request is in flight.
  final HealthStatus? health;

  /// True while [refreshHealth] is running.
  final bool healthLoading;

  /// The last health failure, or null.
  final Object? healthError;

  /// Re-fetches `/health` and rebuilds dependants.
  final Future<void> Function() refreshHealth;

  /// True when the gateway reports `hackathon_mode=true`.
  ///
  /// The gateway owns this flag; the client never guesses it from a build
  /// define. The public demo stays available when it is false.
  final bool hackathonMode;

  /// The current session, or null when exploring anonymously.
  final AuthSession? session;

  /// True while a saved token is being checked on startup.
  final bool authResolving;

  /// Signs in with an email and password, throwing on failure.
  final Future<void> Function(String email, String password) signIn;

  /// Signs into the preseeded judge account, throwing when disabled.
  final Future<void> Function() judgeSignIn;

  /// Revokes the session and returns to the anonymous demo.
  final Future<void> Function() signOut;

  /// The nearest scope, or null when a widget is tested outside [KarumApp].
  static AppScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>();

  /// The nearest scope. Asserts when the widget tree has no [AppScope].
  static AppScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No AppScope found above this widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      client != oldWidget.client ||
      health != oldWidget.health ||
      healthLoading != oldWidget.healthLoading ||
      healthError != oldWidget.healthError ||
      hackathonMode != oldWidget.hackathonMode ||
      session != oldWidget.session ||
      authResolving != oldWidget.authResolving;
}
