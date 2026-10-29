import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karum/main.dart';
import 'package:karum/src/api/gateway_client.dart';

import 'support/fake_gateway.dart';

// PLAN.md §62, end to end: the workspace wires a map pin tap to the board.

/// A gateway whose one skipped venue has a map point, so it gets a pin.
GatewayClient _client() {
  final campaign = campaignJson();
  campaign['skip_list'] = [
    {
      'id': 'd-2',
      'name': "Maggie Mae's",
      'reason': 'low_affinity',
      'lat': 30.2700,
      'lng': -97.7300,
    },
  ];
  return GatewayClient(
    baseUrl: 'http://test',
    httpClient: MockClient((request) async {
      final path = request.url.path;
      if (path == '/health') {
        return jsonResponse({
          'service': 'gateway',
          'status': 'ok',
          'mode': 'fixture',
          'version': 'test',
        });
      }
      if (path == '/api/v1/presets') return jsonResponse(presetsJson());
      if (path == '/api/v1/scout/run-0001') return jsonResponse(campaign);
      return http.Response('stream unavailable', 503);
    }),
  );
}

void main() {
  testWidgets('tapping a skipped pin opens the Skip tab on that row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      KarumApp(client: _client(), initialRoute: '/scout/run-0001'),
    );
    await tester.pumpAndSettle();

    // The board opens on Recommended, where the door card is.
    expect(find.text("Whisler's"), findsWidgets);
    expect(find.text('Below the shortlist floor'), findsNothing);

    await tester.tap(
      find.byTooltip("Maggie Mae's · Below the shortlist floor"),
    );
    await tester.pumpAndSettle();

    // The Skip tab is now showing, with the venue's own row on it.
    expect(find.text('Below the shortlist floor'), findsWidgets);
    expect(find.text("Maggie Mae's"), findsWidgets);
    expect(find.text('Cultural affinity'), findsNothing);
  });
}
