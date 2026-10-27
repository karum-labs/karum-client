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
    await tester.runAsync(() async {
      door = await icons.door(1, selected: false);
      selectedDoor = await icons.door(1, selected: true);
      skip = await icons.skip();
    });

    final doorBitmap = door as BytesMapBitmap;
    final selectedBitmap = selectedDoor as BytesMapBitmap;
    final skipBitmap = skip as BytesMapBitmap;

    expect(doorBitmap.byteData, isNotEmpty);
    expect(selectedBitmap.byteData, isNotEmpty);
    expect(skipBitmap.byteData, isNotEmpty);
    expect(doorBitmap.width, GoogleMarkerIcons.doorSize);
    expect(doorBitmap.height, GoogleMarkerIcons.doorSize);
    expect(selectedBitmap.width, GoogleMarkerIcons.selectedDoorSize);
    expect(skipBitmap.width, GoogleMarkerIcons.skipSize);
    expect(doorBitmap.byteData, isNot(equals(selectedBitmap.byteData)));
    expect(doorBitmap.byteData, isNot(equals(skipBitmap.byteData)));
  });
}
