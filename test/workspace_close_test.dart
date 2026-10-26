import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/main.dart';
import 'package:karum/src/screens/workspace_screen.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'desktop: closing Door board shows a reopen bar, reopening restores it',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gateway = FakeGateway();
      await tester.pumpWidget(
        KarumApp(client: gateway.client(), initialRoute: '/scout/run-0001'),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      // Door board pane is present with its door.
      expect(find.text("Whisler's"), findsOneWidget);

      // Close the Door board pane via its close button.
      final closeBoard = find.byTooltip('Close Door board').first;
      await tester.ensureVisible(closeBoard);
      await tester.tap(closeBoard);
      await tester.pumpAndSettle();

      // The board slot now shows a slim reopen strip with a reopen button.
      expect(find.byType(PaneStrip), findsOneWidget);
      expect(find.text("Whisler's"), findsNothing);
      expect(find.byTooltip('Reopen Door board'), findsOneWidget);

      // Reopen restores the board.
      await tester.tap(find.byTooltip('Reopen Door board').first);
      await tester.pumpAndSettle();
      expect(find.text("Whisler's"), findsOneWidget);
    },
  );

  testWidgets(
    'desktop: closing live trace shows a reopen bar, reopening restores it',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gateway = FakeGateway();
      await tester.pumpWidget(
        KarumApp(client: gateway.client(), initialRoute: '/scout/run-0001'),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.textContaining('stages'), findsOneWidget);

      final closeTrace = find.byTooltip('Close live trace').first;
      await tester.ensureVisible(closeTrace);
      await tester.tap(closeTrace);
      await tester.pumpAndSettle();

      expect(find.byType(PaneStrip), findsOneWidget);
      expect(find.textContaining('stages'), findsNothing);
      expect(find.byTooltip('Reopen Live trace'), findsOneWidget);

      await tester.tap(find.byTooltip('Reopen Live trace').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('stages'), findsOneWidget);
    },
  );

  testWidgets(
    'narrow: closing the trace tab removes it and shows a reopen chip',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gateway = FakeGateway();
      await tester.pumpWidget(
        KarumApp(client: gateway.client(), initialRoute: '/scout/run-0001'),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      // Three tabs are present.
      expect(find.text('Trace (2)'), findsOneWidget);
      expect(find.text('Board (1)'), findsOneWidget);

      // Close the trace tab via its close button in the Trace panel header.
      final closeTrace = find.byTooltip('Close live trace').first;
      await tester.ensureVisible(closeTrace);
      await tester.tap(closeTrace);
      await tester.pumpAndSettle();

      // Trace tab is gone; a reopen chip appears above the tab view.
      expect(find.text('Trace (2)'), findsNothing);
      expect(find.byType(PaneStrip), findsNothing);
      expect(find.byTooltip('Reopen Live trace'), findsOneWidget);

      // Reopen brings the trace tab back.
      await tester.tap(find.byTooltip('Reopen Live trace').first);
      await tester.pumpAndSettle();
      expect(find.text('Trace (2)'), findsOneWidget);
    },
  );

  testWidgets(
    'narrow: closing the Door board tab removes it and shows a reopen chip',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gateway = FakeGateway();
      await tester.pumpWidget(
        KarumApp(client: gateway.client(), initialRoute: '/scout/run-0001'),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('Board (1)'), findsOneWidget);

      // Switch to the board tab so its close button is reachable.
      await tester.tap(find.text('Board (1)').first);
      await tester.pumpAndSettle();

      final closeBoard = find.byTooltip('Close Door board').first;
      await tester.ensureVisible(closeBoard);
      await tester.tap(closeBoard);
      await tester.pumpAndSettle();

      // Board tab is gone; reopen chip appears.
      expect(find.text('Board (1)'), findsNothing);
      expect(find.byTooltip('Reopen Door board'), findsOneWidget);

      await tester.tap(find.byTooltip('Reopen Door board').first);
      await tester.pumpAndSettle();
      expect(find.text('Board (1)'), findsOneWidget);
    },
  );
}
