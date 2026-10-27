import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/src/api/scout_models.dart';
import 'package:karum/src/theme/app_theme.dart';
import 'package:karum/src/widgets/door_board.dart';

void main() {
  testWidgets('door board highlights the selected door card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final campaign = Campaign(
      jobId: 'run-select',
      state: JobState.ready,
      mode: ScoutMode.wholesale,
      city: 'Austin',
      point: GeoPoint(30.2672, -97.7431),
      brand: BrandContext(name: 'Sola'),
      doors: [
        Door(
          id: 'd-1',
          name: 'First Door',
          rank: 1,
          scores: ScoreSet(composite: ScoreTerm(display: 72)),
          place: QlooPlace(
            address: '801 W 6th St, Austin, TX',
            lat: 30.271,
            lng: -97.7501,
          ),
        ),
        Door(
          id: 'd-2',
          name: 'Second Door',
          rank: 2,
          scores: ScoreSet(composite: ScoreTerm(display: 68)),
          place: QlooPlace(
            address: '901 Red River St, Austin, TX',
            lat: 30.265,
            lng: -97.740,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DoorBoard(campaign: campaign, selectedDoorId: 'd-2'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both doors still render.
    expect(find.text('First Door'), findsOneWidget);
    expect(find.text('Second Door'), findsOneWidget);
  });

  testWidgets('door board onSelectDoor is invoked when selection changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final campaign = Campaign(
      jobId: 'run-select',
      state: JobState.ready,
      mode: ScoutMode.wholesale,
      city: 'Austin',
      point: GeoPoint(30.2672, -97.7431),
      brand: BrandContext(name: 'Sola'),
      doors: [
        Door(
          id: 'd-1',
          name: 'First Door',
          rank: 1,
          scores: ScoreSet(composite: ScoreTerm(display: 72)),
          place: QlooPlace(
            address: '801 W 6th St, Austin, TX',
            lat: 30.271,
            lng: -97.7501,
          ),
        ),
      ],
    );

    String? selectedId;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DoorBoard(
            campaign: campaign,
            selectedDoorId: null,
            onSelectDoor: (id) => selectedId = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(selectedId, isNull);
  });
}
