import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karum/src/api/gateway_client.dart';
import 'package:karum/src/screens/home_screen.dart';
import 'package:karum/src/widgets/async_states.dart';

/// Builds a [GatewayClient] whose `/health` responses are driven by [handler].
GatewayClient _clientWith(MockClientHandler handler) =>
    GatewayClient(httpClient: MockClient(handler), baseUrl: 'http://test');

Widget _app(GatewayClient client) =>
    MaterialApp(home: HomeScreen(client: client));

void main() {
  testWidgets('shows loading then a healthy status', (tester) async {
    final client = _clientWith(
      (request) async => http.Response(
        jsonEncode({
          'service': 'gateway',
          'status': 'ok',
          'mode': 'fixture',
          'version': 'test',
          'uptime_seconds': 12,
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await tester.pumpWidget(_app(client));

    // While the future is in flight the loading state is shown.
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the future resolve.
    await tester.pumpAndSettle();

    expect(find.byType(LoadingState), findsNothing);
    // The landing tagline is unique to the body (the AppBar title is separate).
    expect(
      find.text('Brands lose the account by knocking on the wrong door.'),
      findsOneWidget,
    );
    expect(find.textContaining('Previous attempt'), findsOneWidget);
    expect(find.text('gateway'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when the gateway is down', (
    tester,
  ) async {
    final client = _clientWith(
      (request) async => throw http.ClientException('connection refused'),
    );

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Gateway unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('maps a non-200 response onto a specific error', (tester) async {
    final client = _clientWith(
      (request) async => http.Response('slow down', 429),
    );

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    // The 429 must be surfaced with its status, not swallowed as a generic error.
    expect(find.textContaining('429'), findsOneWidget);
  });

  testWidgets('shows a degraded banner when the gateway reports degraded', (
    tester,
  ) async {
    final client = _clientWith(
      (request) async => http.Response(
        jsonEncode({'service': 'gateway', 'status': 'ok', 'mode': 'degraded'}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    expect(find.textContaining('Degraded'), findsOneWidget);
  });

  // PLAN.md §50: a visitor on a replayed run must not read "fixture" or
  // "replay" in the mode badge. The internal mode name stays `fixture`.
  testWidgets('fixture mode reads as a previous attempt, not test data', (
    tester,
  ) async {
    final client = _clientWith(
      (request) async => http.Response(
        jsonEncode({'service': 'gateway', 'status': 'ok', 'mode': 'fixture'}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    expect(find.textContaining('Previous attempt'), findsOneWidget);
    expect(find.textContaining('Fixture mode'), findsNothing);
    expect(find.textContaining('Replaying recorded'), findsNothing);
  });
}
