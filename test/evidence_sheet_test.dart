import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/src/api/scout_models.dart';
import 'package:karum/src/theme/app_theme.dart';
import 'package:karum/src/widgets/evidence_sheet.dart';

/// The drawer must show the evidence service-taste computed: the per-input
/// contributions behind the affinity and the demographic profile.
void main() {
  Widget harness(Campaign campaign, Door door) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showEvidenceSheet(context, campaign: campaign, door: door),
          child: const Text('open'),
        ),
      ),
    ),
  );

  Campaign campaignWith(Door door) => Campaign(
    jobId: 'run-0001',
    state: JobState.ready,
    mode: ScoutMode.wholesale,
    city: 'Austin',
    brand: BrandContext(name: 'Sola'),
    doors: [door],
  );

  testWidgets('the drawer renders the contributions and the demographic profile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final door = Door(
      id: 'd-1',
      name: "Whisler's",
      rank: 1,
      scores: ScoreSet(culturalAffinity: ScoreTerm(value: 0.91, source: 'model_inference')),
      explainability: const [
        Explainability(entityId: 'e-1', label: 'Ilegal Mezcal', score: 0.62),
      ],
      demographics: const Demographics(
        ageBuckets: [DemographicBucket(label: '25_34', delta: 0.12)],
        maleDelta: 0.03,
        femaleDelta: -0.04,
      ),
    );

    await tester.pumpWidget(harness(campaignWith(door), door));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('AFFINITY INPUTS'), findsOneWidget);
    expect(find.text('Ilegal Mezcal'), findsOneWidget);
    expect(find.text('0.620'), findsOneWidget);
    expect(find.text('DEMOGRAPHICS'), findsOneWidget);
    expect(find.text('25_34'), findsOneWidget);
    expect(find.text('+0.12'), findsOneWidget);
    expect(find.text('Male +0.03 · female -0.04'), findsOneWidget);
  });

  testWidgets('a door with no reported evidence says so, and never guesses', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final door = Door(
      id: 'd-2',
      name: 'Here Nor There',
      rank: 1,
      scores: ScoreSet(culturalAffinity: ScoreTerm(value: 0.64, source: 'model_inference')),
    );

    await tester.pumpWidget(harness(campaignWith(door), door));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Qloo reported no per-input contribution'),
      findsOneWidget,
    );
    expect(find.textContaining('No demographic profile came back'), findsOneWidget);
  });
}
