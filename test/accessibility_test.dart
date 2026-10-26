import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/main.dart';
import 'package:karum/src/api/scout_models.dart';
import 'package:karum/src/theme/app_theme.dart';
import 'package:karum/src/theme/brand_tokens.dart';
import 'package:karum/src/widgets/door_board.dart';
import 'package:karum/src/widgets/focus_ring.dart';

import 'support/fake_gateway.dart';

/// The WCAG 2.1 relative contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// The colour a translucent layer actually paints over its backdrop.
Color over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

/// Whether the focused node sits inside [target].
bool _focusIsInside(WidgetTester tester, Finder target) {
  final node = FocusManager.instance.primaryFocus;
  final context = node?.context;
  if (context == null) return false;
  final matches = target.evaluate();
  if (matches.isEmpty) return false;
  final owner = matches.first;
  var found = false;
  context.visitAncestorElements((element) {
    if (element == owner) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Tabs until [target] holds the keyboard focus.
Future<void> tabUntil(
  WidgetTester tester,
  Finder target, {
  int maxTabs = 80,
}) async {
  for (var i = 0; i < maxTabs; i++) {
    if (_focusIsInside(tester, target)) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  fail('$target never took the keyboard focus after $maxTabs tabs');
}

/// A one-door campaign for the screens built directly in a test.
const Campaign _campaign = Campaign(
  jobId: 'run-a11y',
  state: JobState.ready,
  mode: ScoutMode.wholesale,
  city: 'Austin',
  point: GeoPoint(30.2672, -97.7431),
  brand: BrandContext(name: 'Sola'),
  doors: [
    Door(
      id: 'd-1',
      name: "Whisler's",
      rank: 1,
      scores: ScoreSet(composite: ScoreTerm(display: 72)),
      place: QlooPlace(
        address: '307 E 6th St, Austin, TX',
        website: 'https://example.com/whislers',
        phone: '+1 512 555 0100',
        hours: 'Tue 17:00-00:00',
        lat: 30.2672,
        lng: -97.7431,
      ),
    ),
  ],
);

void main() {
  group('contrast', () {
    test('every text pair the app paints clears WCAG AA', () {
      const aa = 4.5;
      final pairs = <String, (Color, Color)>{
        'ink on paper': (KarumColors.ink, KarumColors.paper),
        'ink on surface': (KarumColors.ink, KarumColors.surface),
        'mute on paper': (KarumColors.mute, KarumColors.paper),
        'mute on surface': (KarumColors.mute, KarumColors.surface),
        'brand on paper': (KarumColors.brand, KarumColors.paper),
        'brand on surface': (KarumColors.brand, KarumColors.surface),
        'on brand': (KarumColors.onBrand, KarumColors.brand),
        'approach on paper': (KarumColors.approach, KarumColors.paper),
        'approach on surface': (KarumColors.approach, KarumColors.surface),
        'investigate on paper': (KarumColors.investigate, KarumColors.paper),
        'investigate on surface': (
          KarumColors.investigate,
          KarumColors.surface,
        ),
        'avoid on paper': (KarumColors.avoid, KarumColors.paper),
        'avoid on surface': (KarumColors.avoid, KarumColors.surface),
        'ink on paper (dark)': (KarumColors.inkDark, KarumColors.paperDark),
        'ink on surface (dark)': (KarumColors.inkDark, KarumColors.surfaceDark),
        'mute on paper (dark)': (KarumColors.muteDark, KarumColors.paperDark),
        'mute on surface (dark)': (
          KarumColors.muteDark,
          KarumColors.surfaceDark,
        ),
        'brand on paper (dark)': (KarumColors.brandDark, KarumColors.paperDark),
        'brand on surface (dark)': (
          KarumColors.brandDark,
          KarumColors.surfaceDark,
        ),
        'on brand (dark)': (KarumColors.onBrandDark, KarumColors.brandDark),
      };

      pairs.forEach((name, pair) {
        final ratio = contrastRatio(pair.$1, pair.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(aa),
          reason: '$name is $ratio:1, below the $aa:1 AA minimum',
        );
      });
    });

    test('the selected chip and tag tints stay readable', () {
      // The selected tag paints brand text on a 12% brand wash over the page.
      final wash = over(
        KarumColors.brand.withValues(alpha: 0.12),
        KarumColors.paper,
      );
      expect(
        contrastRatio(KarumColors.brand, wash),
        greaterThanOrEqualTo(4.5),
        reason: 'the selected tag label must clear AA on its own wash',
      );
    });

    test('the theme slots the guide does not name still clear AA', () {
      // Material derives the chip and button slots from the seed colour, so the
      // app inherits colours the brand guide never published. They are read.
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final scheme = theme.colorScheme;
        final pairs = <String, (Color, Color)>{
          'onSurface on surface': (scheme.onSurface, scheme.surface),
          'onSurfaceVariant on surface': (
            scheme.onSurfaceVariant,
            scheme.surface,
          ),
          'onPrimary on primary': (scheme.onPrimary, scheme.primary),
          'onSecondaryContainer on secondaryContainer': (
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
          ),
          'onError on error': (scheme.onError, scheme.error),
        };
        pairs.forEach((name, pair) {
          final ratio = contrastRatio(pair.$1, pair.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$name is $ratio:1 in the ${theme.brightness.name} theme',
          );
        });
      }
    });

    test('the hairline is decorative and carries no meaning', () {
      // The guide marks the line decorative only, so it is not held to a
      // contrast minimum. It is recorded here so the exemption is deliberate.
      expect(
        contrastRatio(KarumColors.line, KarumColors.paper),
        lessThan(4.5),
        reason:
            'the line is a hairline; if this ever fails, it started to '
            'carry meaning and the exemption must be withdrawn',
      );
    });
  });

  group('labels', () {
    testWidgets('every icon button on the landing carries a label', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(KarumApp(client: FakeGateway().client()));
      await tester.pumpAndSettle();

      final buttons = find.byType(IconButton);
      expect(buttons, findsWidgets, reason: 'the landing has icon buttons');
      for (final element in buttons.evaluate()) {
        final button = element.widget as IconButton;
        expect(
          button.tooltip,
          isNotNull,
          reason: 'an IconButton without a tooltip has no pointer hint',
        );
        expect(button.tooltip, isNotEmpty);
        // A tooltip is not an accessible name: Flutter puts it in the tooltip
        // field of the semantics node, and only while it is on screen.
        expect(
          tester
              .getSemantics(find.byElementPredicate((e) => e == element))
              .label,
          isNotEmpty,
          reason:
              'an icon button with no semantic label is announced as an '
              'unlabelled button',
        );
      }
      semantics.dispose();
    });

    testWidgets('every icon button on the board carries a label', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DoorBoard(campaign: _campaign, onRegenerate: (_) {}),
          ),
        ),
      );
      await tester.pump();

      final buttons = find.byType(IconButton);
      expect(buttons, findsWidgets, reason: 'the board has icon buttons');
      for (final element in buttons.evaluate()) {
        final button = element.widget as IconButton;
        expect(button.tooltip, isNotNull);
        expect(button.tooltip, isNotEmpty);
        expect(
          tester
              .getSemantics(find.byElementPredicate((e) => e == element))
              .label,
          isNotEmpty,
          reason:
              'an icon button with no semantic label is announced as an '
              'unlabelled button',
        );
      }
      semantics.dispose();
    });
  });

  group('focus', () {
    testWidgets('the ring follows the keyboard onto the primary action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(KarumApp(client: FakeGateway().client()));
      await tester.pumpAndSettle();

      final submit = find.byKey(const Key('free-entry-submit'));
      expect(submit, findsOneWidget);

      final ring = find.ancestor(of: submit, matching: find.byType(FocusRing));
      expect(
        ring,
        findsOneWidget,
        reason: 'the primary action carries the ring',
      );

      FocusRingState state() => tester.state<FocusRingState>(ring);
      expect(state().focused, isFalse, reason: 'nothing is focused yet');

      await tabUntil(tester, submit);
      expect(state().focused, isTrue, reason: 'the ring follows the focus');
    });

    testWidgets('tabbing reaches the pitch and Enter opens it', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gateway = FakeGateway();
      await tester.pumpWidget(KarumApp(client: gateway.client()));
      await tester.pumpAndSettle();

      // Run the Austin preset so the workspace shows the door board.
      final detail = find.text('Sola Yuzu Mezcal in Austin, TX');
      final austinCard = find.ancestor(of: detail, matching: find.byType(Card));
      final preset = find.descendant(
        of: austinCard,
        matching: find.text('Run again'),
      );
      await tester.ensureVisible(preset);
      await tester.pumpAndSettle();
      await tester.tap(preset);
      await tester.pumpAndSettle();

      final pitch = find.byKey(const Key('door-pitch'));
      expect(pitch, findsOneWidget, reason: 'the board offers the pitch');

      await tabUntil(tester, pitch);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(
        find.text('Copy script'),
        findsOneWidget,
        reason: 'Enter on the pitch action opens the door card',
      );
    });

    testWidgets('the map pins are not tab stops', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gateway = FakeGateway();
      await tester.pumpWidget(KarumApp(client: gateway.client()));
      await tester.pumpAndSettle();

      final detail = find.text('Sola Yuzu Mezcal in Austin, TX');
      final austinCard = find.ancestor(of: detail, matching: find.byType(Card));
      final preset = find.descendant(
        of: austinCard,
        matching: find.text('Run again'),
      );
      await tester.ensureVisible(preset);
      await tester.pumpAndSettle();
      await tester.tap(preset);
      await tester.pumpAndSettle();

      final map = find.byType(MarkerLayer);
      expect(map, findsOneWidget, reason: 'the workspace draws the map');

      // Walk the whole judge path and record where the focus lands.
      final visited = <String>[];
      for (var i = 0; i < 40; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final node = FocusManager.instance.primaryFocus;
        if (node == null) break;
        final context = node.context;
        if (context == null) break;
        final inMap =
            context.findAncestorWidgetOfExactType<MarkerLayer>() != null;
        expect(
          inMap,
          isFalse,
          reason:
              'the keyboard must not land on a map pin; the list view '
              'carries the same doors in the same order',
        );
        final label = node.debugLabel;
        if (label != null && visited.isNotEmpty && visited.last != label) {
          visited.add(label);
        }
      }
    });
  });

  group('tap targets', () {
    testWidgets('the landing meets the labelled tap target guideline', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(KarumApp(client: FakeGateway().client()));
      await tester.pumpAndSettle();

      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('the board meets the labelled tap target guideline', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DoorBoard(campaign: _campaign, onRegenerate: (_) {}),
          ),
        ),
      );
      await tester.pump();

      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('the workspace meets the labelled tap target guideline', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        KarumApp(
          client: FakeGateway().client(),
          initialRoute: '/scout/run-0001',
        ),
      );
      await tester.pumpAndSettle();

      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
