import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/main.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets('find overflowing rows at 420 wide', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = FakeGateway();
    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/scout/run-0001'),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    tester.takeException();

    for (final element in find.byType(Row).evaluate()) {
      final render = element.renderObject;
      if (render is! RenderFlex) continue;
      if (render.size.height > 24) continue;
      var total = 0.0;
      var child = render.firstChild;
      while (child != null) {
        final data = child.parentData! as FlexParentData;
        final flex = data.flex;
        if (flex == null || flex == 0) total += child.size.width;
        child = data.nextSibling;
      }
      if (total > render.size.width + 1 || render.size.width >= 300) {
        debugPrint(
          'ROW size=${render.size} constraints=${render.constraints} '
          'total=$total creator=${render.debugCreator}',
        );
        debugPrint(render.toStringDeep());
      }
    }
  });
}
