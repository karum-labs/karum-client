import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/main.dart';
import 'package:karum/src/api/scout_models.dart';
import 'package:karum/src/theme/app_theme.dart';
import 'package:karum/src/widgets/door_board.dart';

import 'support/fake_gateway.dart';

/// A campaign with a long door name, a Places address, a source badge, and a
/// skip row — the parts that carry the most intrinsic width on the board.
const Campaign _campaign = Campaign(
  jobId: 'run-narrow',
  state: JobState.ready,
  mode: ScoutMode.wholesale,
  city: 'Austin, TX, US',
  point: GeoPoint(30.2672, -97.7431),
  brand: BrandContext(name: 'Sola Yuzu Mezcal'),
  doors: [
    Door(
      id: 'd-1',
      name: "Whisler's Bar & Terrace",
      rank: 1,
      scores: ScoreSet(composite: ScoreTerm(display: 72)),
      place: QlooPlace(
        address: '307 E 6th St, Austin, TX 78701',
        website: 'https://example.com/whislers',
        phone: '+1 512 555 0100',
        hours: 'Tue 17:00-00:00',
        lat: 30.2672,
        lng: -97.7431,
      ),
      sharedTags: [
        KarumTag(urn: 'urn:tag:genre:place:restaurant:bar', label: 'Bars'),
      ],
    ),
  ],
  skipList: [
    SkipItem(
      id: 'd-2',
      name: "Maggie Mae's",
      reason: 'low_affinity',
      reasonDetail: '0.8160 below the returned floor 0.8386',
      rawAffinity: 0.816,
      floor: 0.8386,
    ),
  ],
);

void main() {
  testWidgets('the landing screen lays out at 320 x 640', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = FakeGateway();
    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    // Both hero actions are on screen, and the page laid out without a
    // RenderFlex overflow stripe.
    expect(find.text('Load a sample'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the door board lays out at 320 x 640', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: DoorBoard(campaign: _campaign)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Whisler's Bar & Terrace"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the skip tab shows the gateway reason detail', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: DoorBoard(campaign: _campaign)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip (1)'));
    await tester.pumpAndSettle();

    expect(find.text('0.8160 below the returned floor 0.8386'), findsOneWidget);
    expect(find.text("Maggie Mae's"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
