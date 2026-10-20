import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/main.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets('judge path: preset click lands on a ready door board', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = FakeGateway();
    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    // The landing renders the locked samples.
    final preset = find.text('Try Sample: Sola Yuzu Mezcal in Austin, TX');
    expect(preset, findsOneWidget);

    await tester.ensureVisible(preset);
    await tester.pumpAndSettle();
    await tester.tap(preset);
    await tester.pumpAndSettle();

    // One POST, locked to the preset, carrying an idempotency key.
    expect(gateway.scoutPosts, hasLength(1));
    final body =
        jsonDecode(gateway.scoutPosts.single.body) as Map<String, dynamic>;
    expect(body['preset_id'], 'austin-wholesale');
    expect(body.containsKey('free_entry'), isFalse);
    expect(gateway.scoutPosts.single.headers['Idempotency-Key'], isNotEmpty);

    // The workspace shows the fixture banner and the ranked door.
    expect(find.textContaining('Fixture mode'), findsOneWidget);
    expect(find.text('Ready'), findsWidgets);
    expect(find.text("Whisler's"), findsWidgets);
    expect(find.textContaining('Whisler'), findsWidgets);
    // Menu findings carry clickable grounding citations on the card.
    expect(find.text('Spring menu'), findsOneWidget);
  });

  testWidgets('inspecting a sample carries its stored point into free entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = FakeGateway();
    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    final inspect = find.text('Inspect this seed').first;
    await tester.ensureVisible(inspect);
    await tester.pumpAndSettle();
    await tester.tap(inspect);
    await tester.pumpAndSettle();

    final submit = find.text('Run this scout');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(gateway.scoutPosts, hasLength(1));
    final body =
        jsonDecode(gateway.scoutPosts.single.body) as Map<String, dynamic>;
    expect(body['free_entry'], isTrue);
    expect(body['point'], {'lat': 30.2672, 'lng': -97.7431});
    expect(body['seed_entities'], isNotEmpty);
  });

  testWidgets('free entry refuses an empty city without calling the gateway', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = FakeGateway();
    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    final submit = find.text('Run this scout');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Add a city before running the scout.'), findsOneWidget);
    expect(gateway.scoutPosts, isEmpty);
  });

  testWidgets('a dropped trace stream falls back to polling', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = FakeGateway(runningFetches: 2);
    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/scout/run-0001'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The SSE 503 surfaces as a dropped-stream notice while the job runs.
    expect(find.textContaining('Trace stream dropped'), findsOneWidget);

    // The poller then picks up the ready campaign and the notice clears.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(find.text("Whisler's"), findsWidgets);
    expect(find.textContaining('Trace stream dropped'), findsNothing);
  });

  testWidgets('workspace lays out at a narrow 420 x 900 window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = FakeGateway();
    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/scout/run-0001'),
    );
    await tester.pumpAndSettle();

    // Below 1200 px the workspace uses trace/map/board tabs.
    expect(find.text('Trace (2)'), findsOneWidget);
    expect(find.text('Board (1)'), findsOneWidget);

    await tester.tap(find.text('Board (1)'));
    await tester.pumpAndSettle();
    expect(find.text("Whisler's"), findsWidgets);
  });
}
