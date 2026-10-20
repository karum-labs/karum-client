import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/src/api/scout_models.dart';
import 'package:karum/src/theme/app_theme.dart';
import 'package:karum/src/widgets/map_panel.dart';

void main() {
  testWidgets('map draws recorded skip pins and locality polygons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final campaign = Campaign(
      jobId: 'run-map',
      state: JobState.ready,
      mode: ScoutMode.flagship,
      city: 'Austin',
      point: const GeoPoint(30.2672, -97.7431),
      radiusMeters: 8000,
      brand: const BrandContext(name: 'Sola'),
      doors: [
        const Door(
          id: 'd-1',
          name: "Whisler's",
          rank: 1,
          scores: ScoreSet(composite: ScoreTerm(display: 72)),
          place: QlooPlace(
            address: '307 E 6th St',
            lat: 30.2672,
            lng: -97.7431,
          ),
        ),
      ],
      skipList: const [
        SkipItem(
          id: 'd-2',
          name: "Maggie Mae's",
          reason: 'low_affinity',
          lat: 30.2676,
          lng: -97.7387,
        ),
      ],
      heatmap: const Heatmap(
        available: true,
        cellCount: 1,
        cells: [
          HeatmapCell(point: GeoPoint(30.262, -97.727), affinity: 0.8, rank: 1),
        ],
        localities: [
          LocalityPolygon(
            name: 'East Austin',
            affinity: 0.8,
            centroid: GeoPoint(30.262, -97.727),
            polygon: [
              GeoPoint(30.25, -97.74),
              GeoPoint(30.27, -97.74),
              GeoPoint(30.27, -97.71),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: MapPanel(campaign: campaign)),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate((widget) => widget is PolygonLayer),
      findsOneWidget,
    );
    expect(find.text('Qloo locality'), findsOneWidget);
    expect(find.text('Skipped door'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        "Skipped door Maggie Mae's: Below the shortlist floor",
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel("Recommended door 1: Whisler's"),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
