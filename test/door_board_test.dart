import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/src/api/scout_models.dart';
import 'package:karum/src/theme/app_theme.dart';
import 'package:karum/src/widgets/door_board.dart';

void main() {
  testWidgets('door card hydrates missing Places fields from Qloo facts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const campaign = Campaign(
      jobId: 'run-card',
      state: JobState.ready,
      mode: ScoutMode.wholesale,
      city: 'Austin',
      point: GeoPoint(30.2672, -97.7431),
      brand: BrandContext(name: 'Sola'),
      doors: [
        Door(
          id: 'd-1',
          name: 'Here Nor There',
          rank: 1,
          scores: ScoreSet(composite: ScoreTerm(display: 72)),
          place: QlooPlace(
            address: '801 W 6th St, Austin, TX',
            website: 'https://example.com/here-nor-there',
            phone: '+1 512 555 0199',
            hours: 'Tue 17:00-00:00',
            lat: 30.271,
            lng: -97.7501,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: DoorBoard(campaign: campaign)),
      ),
    );
    await tester.pump();

    expect(find.text('801 W 6th St, Austin, TX'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('+1 512 555 0199'), findsOneWidget);
    expect(find.text('Tue 17:00-00:00'), findsOneWidget);
    expect(find.text('Qloo fact'), findsWidgets);
  });

  testWidgets('a renormalized composite is labelled partial', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const campaign = Campaign(
      jobId: 'run-partial',
      state: JobState.ready,
      mode: ScoutMode.wholesale,
      city: 'Austin',
      brand: BrandContext(name: 'Sola'),
      doors: [
        Door(
          id: 'd-1',
          name: 'Tobalá',
          rank: 1,
          scores: ScoreSet(composite: ScoreTerm(display: 100, partial: true)),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: DoorBoard(campaign: campaign)),
      ),
    );
    await tester.pump();

    expect(find.text('Partial composite'), findsOneWidget);
  });

  testWidgets('a door with no pitch offers to generate one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const campaign = Campaign(
      jobId: 'run-nopitch',
      state: JobState.ready,
      mode: ScoutMode.wholesale,
      city: 'Austin',
      point: GeoPoint(30.2672, -97.7431),
      brand: BrandContext(name: 'Sola'),
      doors: [
        Door(
          id: 'd-1',
          name: 'Here Nor There',
          rank: 1,
          scores: ScoreSet(composite: ScoreTerm(display: 72)),
        ),
      ],
    );
    Door? requested;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DoorBoard(
            campaign: campaign,
            onRegenerate: (door) => requested = door,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('No pitch yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('door-generate-pitch')));
    expect(requested?.id, 'd-1');
  });
}
