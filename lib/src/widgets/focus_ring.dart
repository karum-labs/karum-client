import 'package:flutter/material.dart';

import '../theme/brand_tokens.dart';

/// The brand guide's focus treatment: 3 px of brand colour, 2 px away from the
/// control.
///
/// The guide publishes this as an **official** token pair — [KarumBrand
/// .focusRingWidth] and [KarumBrand.focusRingOffset] — and the offset is the
/// part that matters. A ring drawn on the control's own edge would be brand on
/// brand for a filled button and would not read at all; the 2 px gap leaves the
/// page showing between the control and the ring, so the ring is a mark in its
/// own right.
///
/// Flutter has no `outline-offset`, so the ring is painted outside the child's
/// bounds by a [CustomPainter]. Painting outside the layout box means the ring
/// costs no space and moving focus never reflows the page.
class FocusRing extends StatefulWidget {
  /// Wraps [child] so the guide's ring is drawn around it while it has focus.
  const FocusRing({super.key, required this.child, this.borderRadius});

  /// The control the ring belongs to.
  final Widget child;

  /// The control's corner radius, so the ring follows the control's shape.
  final BorderRadius? borderRadius;

  @override
  State<FocusRing> createState() => FocusRingState();
}

/// The state of a [FocusRing], exposed so a test can assert the ring is drawn.
class FocusRingState extends State<FocusRing> {
  bool _focused = false;

  /// Whether the ring is currently drawn.
  ///
  /// True when the wrapped control — or anything inside it — holds focus. The
  /// ring follows the focus rather than the press, because the ring is the
  /// keyboard's marker.
  bool get focused => _focused;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Focus(
      // The node is a watcher, not a stop: it must never take focus itself, but
      // `hasFocus` is true while a descendant holds it.
      canRequestFocus: false,
      onFocusChange: (value) {
        if (value != _focused) setState(() => _focused = value);
      },
      child: CustomPaint(
        foregroundPainter: _FocusRingPainter(
          focused: _focused,
          color: palette.brand,
          width: KarumBrand.focusRingWidth,
          offset: KarumBrand.focusRingOffset,
          radius: widget.borderRadius ?? BorderRadius.zero,
        ),
        child: widget.child,
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({
    required this.focused,
    required this.color,
    required this.width,
    required this.offset,
    required this.radius,
  });

  final bool focused;
  final Color color;
  final double width;
  final double offset;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (!focused) return;
    // The stroke is centred on its path, so the path sits half a stroke further
    // out than the gap: the ring's inner edge lands exactly `offset` from the
    // control and its outer edge `offset + width` from it.
    final rrect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: radius.topLeft,
      topRight: radius.topRight,
      bottomLeft: radius.bottomLeft,
      bottomRight: radius.bottomRight,
    ).inflate(offset + width / 2);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.focused != focused ||
      old.color != color ||
      old.width != width ||
      old.offset != offset ||
      old.radius != radius;
}
