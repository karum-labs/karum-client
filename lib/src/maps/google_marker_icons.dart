import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/brand_tokens.dart';

/// Renders the marker symbols the Google map uses.
///
/// Google's web plugin ignores [BitmapDescriptor.defaultMarkerWithHue], so
/// every default marker renders as the same red pin. These bitmaps are drawn
/// explicitly and handed to [BitmapDescriptor.bytes], which the web plugin
/// supports. Recommended doors get a numbered circle; skipped venues get a
/// filled disc in the Avoid colour with a minus. Both kinds share one size at
/// every state, so a skipped pin reads as the twin of a recommended one and
/// the minus and colour, not size, mark it as skipped.
class GoogleMarkerIcons {
  GoogleMarkerIcons(this.palette);

  final KarumPalette palette;

  static const double doorSize = 36;
  static const double selectedDoorSize = 44;

  static String doorKey(int rank, {required bool selected}) =>
      'door:$rank:$selected';
  static String skipKey({required bool selected}) => 'skip:$selected';

  final Map<String, Future<BitmapDescriptor>> _cache = {};

  Future<BitmapDescriptor> door(int rank, {required bool selected}) {
    return _cache.putIfAbsent(
      doorKey(rank, selected: selected),
      () => _renderDoor(rank, selected: selected),
    );
  }

  Future<BitmapDescriptor> skip({bool selected = false}) {
    return _cache.putIfAbsent(
      skipKey(selected: selected),
      () => _renderSkip(selected: selected),
    );
  }

  Future<BitmapDescriptor> _renderDoor(
    int rank, {
    required bool selected,
  }) async {
    final size = selected ? selectedDoorSize : doorSize;
    final bytes = await _render(
      size: size,
      draw: (canvas, center, radius, scale) {
        canvas.drawCircle(
          center.translate(0, 1.5 * scale),
          radius,
          ui.Paint()
            ..color = palette.ink.withValues(alpha: 0.16)
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5 * scale),
        );
        canvas.drawCircle(
          center,
          radius,
          ui.Paint()..color = selected ? palette.brand : palette.surface,
        );
        canvas.drawCircle(
          center,
          radius,
          ui.Paint()
            ..color = selected ? palette.surface : palette.brand
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2 * scale,
        );
        final label = TextPainter(
          text: TextSpan(
            text: '$rank',
            style: TextStyle(
              color: selected ? palette.onBrand : palette.brand,
              fontFamily: KarumFonts.body,
              fontSize: radius * 0.82,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
      },
    );
    return BitmapDescriptor.bytes(bytes, width: size, height: size);
  }

  Future<BitmapDescriptor> _renderSkip({required bool selected}) async {
    final size = selected ? selectedDoorSize : doorSize;
    final bytes = await _render(
      size: size,
      draw: (canvas, center, radius, scale) {
        canvas.drawCircle(
          center.translate(0, 1.5 * scale),
          radius,
          ui.Paint()
            ..color = palette.ink.withValues(alpha: 0.16)
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5 * scale),
        );
        canvas.drawCircle(center, radius, ui.Paint()..color = palette.avoid);
        // The ring echoes the door marker's edge: the surface colour when
        // selected, the fill colour otherwise.
        canvas.drawCircle(
          center,
          radius,
          ui.Paint()
            ..color = selected ? palette.surface : palette.avoid
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2 * scale,
        );
        // The minus is knocked out in the surface colour, which clears AA on
        // the Avoid fill in both palettes (7.41:1 light, 7.04:1 dark).
        final half = radius * 0.42;
        canvas.drawLine(
          center.translate(-half, 0),
          center.translate(half, 0),
          ui.Paint()
            ..color = palette.surface
            ..strokeWidth = 2.6 * scale
            ..strokeCap = ui.StrokeCap.round,
        );
      },
    );
    return BitmapDescriptor.bytes(bytes, width: size, height: size);
  }

  Future<Uint8List> _render({
    required double size,
    required void Function(
      ui.Canvas canvas,
      Offset center,
      double radius,
      double scale,
    )
    draw,
  }) async {
    const scale = 3.0;
    final pixels = (size * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final center = Offset(pixels / 2, pixels / 2);
    // Leave a small transparent margin so the bitmap can carry a soft shadow.
    final radius = pixels / 2 - 2.5 * scale;
    draw(canvas, center, radius, scale);
    final picture = recorder.endRecording();
    final image = await picture.toImage(pixels, pixels);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      throw StateError('Could not encode a Google Maps marker icon.');
    }
    return data.buffer.asUint8List();
  }
}
