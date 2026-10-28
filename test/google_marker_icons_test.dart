import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:karum/src/maps/google_marker_icons.dart';
import 'package:karum/src/theme/brand_tokens.dart';

void main() {
  testWidgets('door and skip markers use distinct bitmaps', (tester) async {
    final icons = GoogleMarkerIcons(KarumPalette.light);
    late BitmapDescriptor door;
    late BitmapDescriptor selectedDoor;
    late BitmapDescriptor skip;
    late BitmapDescriptor selectedSkip;
    await tester.runAsync(() async {
      door = await icons.door(1, selected: false);
      selectedDoor = await icons.door(1, selected: true);
      skip = await icons.skip();
      selectedSkip = await icons.skip(selected: true);
    });

    final doorBitmap = door as BytesMapBitmap;
    final selectedBitmap = selectedDoor as BytesMapBitmap;
    final skipBitmap = skip as BytesMapBitmap;
    final selectedSkipBitmap = selectedSkip as BytesMapBitmap;

    expect(doorBitmap.byteData, isNotEmpty);
    expect(selectedBitmap.byteData, isNotEmpty);
    expect(skipBitmap.byteData, isNotEmpty);
    expect(doorBitmap.width, GoogleMarkerIcons.doorSize);
    expect(doorBitmap.height, GoogleMarkerIcons.doorSize);
    expect(selectedBitmap.width, GoogleMarkerIcons.selectedDoorSize);
    // A skipped pin is the same size as a recommended one at every state
    // (PLAN.md §61), so the two kinds are told apart by colour and minus.
    expect(skipBitmap.width, doorBitmap.width);
    expect(skipBitmap.height, doorBitmap.height);
    expect(selectedSkipBitmap.width, selectedBitmap.width);
    expect(selectedSkipBitmap.height, selectedBitmap.height);
    expect(skipBitmap.byteData, isNot(equals(selectedSkipBitmap.byteData)));
    expect(doorBitmap.byteData, isNot(equals(selectedBitmap.byteData)));
    expect(doorBitmap.byteData, isNot(equals(skipBitmap.byteData)));
  });
}
