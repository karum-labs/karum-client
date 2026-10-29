import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/src/api/scout_models.dart';
import 'package:karum/src/theme/app_theme.dart';
import 'package:karum/src/widgets/door_board.dart';
import 'package:karum/src/widgets/map_panel.dart';
import 'package:karum/src/widgets/map_selection.dart';

// PLAN.md §62: a pin tap brings the matching board tab forward and scrolls to
// the entry, whichever tab was showing and however far down the entry is.

Campaign _campaign({int doors = 12, int skips = 40}) => Campaign(
  jobId: 'run-pins',
  state: JobState.ready,
  mode: ScoutMode.wholesale,
  city: 'Austin',
  point: const GeoPoint(30.2672, -97.7431),
  radiusMeters: 8000,
  brand: const BrandContext(name: 'Sola'),
  doors: [
    for (var i = 1; i <= doors; i++)
      Door(
        id: 'd-$i',
        name: 'Door number $i',
        rank: i,
        scores: const ScoreSet(composite: ScoreTerm(display: 70)),
        place: QlooPlace(
          address: '$i Main St',
          lat: 30.26 + i * 0.001,
          lng: -97.74,
        ),
      ),
  ],
  skipList: [
    for (var i = 0; i < skips; i++)
      SkipItem(
        id: 's-$i',
        name: 'Skipped venue $i',
        reason: 'low_affinity',
        lat: 30.27 + i * 0.001,
        lng: -97.73 + i * 0.02,
      ),
  ],
);

/// Hosts a board whose selection a test changes from outside, the way the
/// workspace changes it when a pin is tapped.
class _Harness extends StatefulWidget {
  const _Harness({required this.campaign});

  final Campaign campaign;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String? doorId;
  String? skipId;
  int nonce = 0;

  void tapDoor(String id) => setState(() {
    doorId = id;
    skipId = null;
    nonce++;
  });

  void tapSkip(int index) => setState(() {
    skipId = skipSelectionId(index, widget.campaign.skipList[index]);
    doorId = null;
    nonce++;
  });

  @override
  Widget build(BuildContext context) => DoorBoard(
    campaign: widget.campaign,
    selectedDoorId: doorId,
    selectedSkipId: skipId,
    selectionNonce: nonce,
    onSelectDoor: (_) {},
  );
}

Future<_HarnessState> _pump(WidgetTester tester, Campaign campaign) async {
  tester.view.physicalSize = const Size(480, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: _Harness(campaign: campaign)),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<_HarnessState>(find.byType(_Harness));
}

/// True when [finder] sits fully inside the scroll view that holds it — that
/// is, it is built and has been scrolled into the visible part of the list.
bool _visible(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return false;
  final holder = find.ancestor(
    of: finder.first,
    matching: find.byType(SingleChildScrollView),
  );
  if (holder.evaluate().isEmpty) return false;
  final row = tester.getRect(finder.first);
  final viewport = tester.getRect(holder.first);
  return row.top >= viewport.top && row.bottom <= viewport.bottom;
}

void main() {
  testWidgets('a skip pin tap on the Recommended tab opens Skip and scrolls', (
    tester,
  ) async {
    final harness = await _pump(tester, _campaign());
    expect(find.text('Door number 1'), findsOneWidget);

    harness.tapSkip(30);
    await tester.pumpAndSettle();

    expect(find.text('Skipped venue 30'), findsOneWidget);
    expect(_visible(tester, find.text('Skipped venue 30')), isTrue);
    // The Recommended tab is no longer the one showing.
    expect(find.text('Door number 1'), findsNothing);
  });

  testWidgets('the last skipped row of a long list is reachable', (
    tester,
  ) async {
    final harness = await _pump(tester, _campaign(skips: 40));
    harness.tapSkip(39);
    await tester.pumpAndSettle();
    expect(_visible(tester, find.text('Skipped venue 39')), isTrue);
  });

  testWidgets('a door pin tap on the Skip tab opens Recommended and scrolls', (
    tester,
  ) async {
    final harness = await _pump(tester, _campaign());
    // Land on the Skip tab first, as a visitor who had been reading skips.
    harness.tapSkip(2);
    await tester.pumpAndSettle();
    expect(find.text('Skipped venue 2'), findsOneWidget);

    harness.tapDoor('d-11');
    await tester.pumpAndSettle();

    expect(find.text('Door number 11'), findsOneWidget);
    expect(_visible(tester, find.text('Door number 11')), isTrue);
    expect(find.text('Skipped venue 2'), findsNothing);
  });

  testWidgets('tapping the same pin again scrolls back to it', (tester) async {
    final harness = await _pump(tester, _campaign());
    harness.tapSkip(25);
    await tester.pumpAndSettle();
    expect(_visible(tester, find.text('Skipped venue 25')), isTrue);

    // The visitor scrolls the list away from the entry.
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, 4000),
    );
    await tester.pumpAndSettle();
    expect(_visible(tester, find.text('Skipped venue 25')), isFalse);

    harness.tapSkip(25);
    await tester.pumpAndSettle();
    expect(_visible(tester, find.text('Skipped venue 25')), isTrue);
  });

  testWidgets('a board built with a selection already set opens at it', (
    tester,
  ) async {
    // The narrow layout builds the board only once the visitor opens its tab;
    // by then the pin has been tapped, so the board must honour the selection.
    final campaign = _campaign();
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DoorBoard(
            campaign: campaign,
            selectedSkipId: skipSelectionId(35, campaign.skipList[35]),
            selectionNonce: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_visible(tester, find.text('Skipped venue 35')), isTrue);
  });

  testWidgets('a skipped pin on the fallback map reports its selection id', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final campaign = _campaign(doors: 1, skips: 3);
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MapPanel(campaign: campaign, onSelectSkip: (id) => tapped = id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byTooltip('Skipped venue 1 · Below the shortlist floor'),
    );
    await tester.pumpAndSettle();

    // The id comes from the position in the full skip list, which is what the
    // board uses, not from the map's own filtered list.
    expect(tapped, skipSelectionId(1, campaign.skipList[1]));
  });
}
