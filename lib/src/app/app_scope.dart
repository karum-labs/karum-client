import 'package:flutter/widgets.dart';

import '../api/gateway_client.dart';
import '../api/health_status.dart';

/// The gateway client and health snapshot shared by every route.
///
/// Routes read this instead of constructing their own client, so a health retry
/// or an injected test client reaches the whole tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.client,
    required this.health,
    required this.healthLoading,
    required this.healthError,
    required this.refreshHealth,
    required this.hackathonMode,
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

  /// True when the client-level hackathon flag is on. The gateway currently
  /// exposes no equivalent flag; see PLAN.md §28.
  final bool hackathonMode;

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
      hackathonMode != oldWidget.hackathonMode;
}
