import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../theme/brand_tokens.dart';
import '../util/links.dart';
import '../widgets/common.dart';
import '../widgets/focus_ring.dart';
import 'place_detail.dart';

/// What Karum itself knows about the pin the bubble belongs to.
///
/// This comes from the run payload, so it is on screen the moment the bubble
/// opens, before the Places lookup has answered. It carries its own source
/// label; the Places block carries a different one.
class PlaceBubbleFacts {
  const PlaceBubbleFacts.door({
    required this.title,
    required int this.rank,
    this.score,
    this.scoreSource = 'model_inference',
    this.sharedTags = const [],
    this.onOpenPitch,
  }) : skipped = false,
       reason = '',
       reasonDetail = '';

  const PlaceBubbleFacts.skipped({
    required this.title,
    required this.reason,
    this.reasonDetail = '',
  }) : skipped = true,
       rank = null,
       score = null,
       scoreSource = '',
       sharedTags = const [],
       onOpenPitch = null;

  final String title;
  final bool skipped;

  /// A recommended door's rank, and its composite score out of 100.
  final int? rank;
  final num? score;
  final String scoreSource;

  /// The taste tags the door shares with the brand's seed.
  final List<String> sharedTags;

  /// A skipped venue's plain-English reason and the numbers behind it.
  final String reason;
  final String reasonDetail;

  /// Opens the door's pitch and route; null for a skipped venue.
  final VoidCallback? onOpenPitch;
}

/// Where the bubble goes relative to its pin.
class BubblePlacement {
  const BubblePlacement({
    required this.visible,
    required this.above,
    required this.left,
    required this.width,
    required this.maxHeight,
    required this.tailX,
    required this.edge,
  });

  /// False when the pin is outside the map, so the bubble has nothing to point
  /// at and is not drawn.
  final bool visible;

  /// True when the bubble sits above the pin, false when it flipped below.
  final bool above;

  /// The bubble's left edge in the map's coordinates, and its width.
  final double left;
  final double width;
  final double maxHeight;

  /// Where the tail meets the bubble, measured from the bubble's left edge.
  final double tailX;

  /// The bubble's near edge: its bottom edge's y when [above], its top edge's y
  /// when below, in the map's coordinates.
  final double edge;
}

/// Works out where a bubble for a pin at [anchor] goes inside [map].
///
/// It prefers above the pin and flips below when there is not room, keeps the
/// bubble inside [margin] (the top margin clears the map legend, the right one
/// the zoom controls), and points the tail at the pin however far the bubble
/// had to slide to stay inside.
BubblePlacement placeBubble({
  required Offset anchor,
  required Size map,
  double width = 380,
  double markerRadius = 22,
  double gap = 12,
  EdgeInsets margin = const EdgeInsets.fromLTRB(12, 56, 64, 16),
  double comfortableHeight = 240,
  double maxHeight = 520,
}) {
  final onMap = Rect.fromLTWH(
    0,
    0,
    map.width,
    map.height,
  ).inflate(markerRadius).contains(anchor);
  final usable = map.width - margin.left - margin.right;
  final w = width < usable ? width : (usable < 220 ? 220.0 : usable);
  final upper = margin.left;
  final lower = map.width - margin.right - w;
  final left = lower < upper
      ? upper
      : (anchor.dx - w / 2).clamp(upper, lower).toDouble();

  final spaceAbove = anchor.dy - markerRadius - gap - margin.top;
  final spaceBelow =
      map.height - margin.bottom - (anchor.dy + markerRadius + gap);
  final above = spaceAbove >= comfortableHeight || spaceAbove >= spaceBelow;
  final room = above ? spaceAbove : spaceBelow;
  return BubblePlacement(
    visible: onMap,
    above: above,
    left: left,
    width: w,
    maxHeight: room.clamp(120.0, maxHeight).toDouble(),
    tailX: (anchor.dx - left).clamp(18.0, w - 18).toDouble(),
    edge: above
        ? anchor.dy - markerRadius - gap
        : anchor.dy + markerRadius + gap,
  );
}

/// Draws a [PlaceBubbleCard] over the map at [anchor], with a tail to the pin.
///
/// [anchor] is the pin's position in the map's own coordinates; null hides the
/// bubble. The card owns what it shows; this widget owns only where.
class PlaceBubbleLayer extends StatelessWidget {
  const PlaceBubbleLayer({
    super.key,
    required this.anchor,
    required this.mapSize,
    required this.facts,
    required this.details,
    required this.onClose,
    this.repository,
  });

  final Offset? anchor;
  final Size mapSize;
  final PlaceBubbleFacts facts;
  final Future<PlaceDetails?> details;
  final VoidCallback onClose;
  final PlaceDetailsRepository? repository;

  static const double _tail = 11;

  @override
  Widget build(BuildContext context) {
    final point = anchor;
    if (point == null) return const SizedBox.shrink();
    final placement = placeBubble(anchor: point, map: mapSize);
    if (!placement.visible) return const SizedBox.shrink();
    final palette = KarumPalette.of(context);

    // On the web the Google map is a platform view underneath Flutter. Wheel
    // and pointer events over an ordinary Flutter widget still reach the map's
    // DOM element, so scrolling the bubble also zooms the map. PointerInterceptor
    // puts an invisible element over the card so those events stop at it
    // (PLAN.md §63). On mobile it is a plain pass-through.
    final card = PointerInterceptor(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: placement.maxHeight),
        child: PlaceBubbleCard(
          facts: facts,
          details: details,
          onClose: onClose,
          repository: repository,
        ),
      ),
    );
    final tailLeft = placement.left + placement.tailX - _tail;
    final tail = PointerInterceptor(
      child: CustomPaint(
        size: const Size(_tail * 2, _tail),
        painter: _TailPainter(
          fill: palette.surface,
          line: palette.line,
          pointsDown: placement.above,
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (placement.above) ...[
          Positioned(
            left: placement.left,
            width: placement.width,
            bottom: mapSize.height - placement.edge,
            child: card,
          ),
          // The tail overlaps the card's edge by a pixel so the border does
          // not show as a line across its base.
          Positioned(
            left: tailLeft,
            bottom: mapSize.height - placement.edge - _tail + 1,
            child: IgnorePointer(child: tail),
          ),
        ] else ...[
          Positioned(
            left: placement.left,
            width: placement.width,
            top: placement.edge,
            child: card,
          ),
          Positioned(
            left: tailLeft,
            top: placement.edge - _tail + 1,
            child: IgnorePointer(child: tail),
          ),
        ],
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({
    required this.fill,
    required this.line,
    required this.pointsDown,
  });

  final Color fill;
  final Color line;
  final bool pointsDown;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsDown) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    } else {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    }
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Cover the stroke along the base so it joins the card's own edge.
    canvas.drawLine(
      Offset(1, pointsDown ? 0 : size.height),
      Offset(size.width - 1, pointsDown ? 0 : size.height),
      Paint()
        ..color = fill
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) =>
      old.fill != fill || old.line != line || old.pointsDown != pointsDown;
}

/// The bubble's contents: Karum's own facts at once, then the Places lookup as
/// it arrives.
///
/// A slow or failed lookup never leaves the tap looking dead: the Karum facts
/// are already there, and a failure adds one quiet line, not a snackbar.
class PlaceBubbleCard extends StatefulWidget {
  const PlaceBubbleCard({
    super.key,
    required this.facts,
    required this.details,
    required this.onClose,
    this.repository,
  });

  final PlaceBubbleFacts facts;
  final Future<PlaceDetails?> details;
  final VoidCallback onClose;
  final PlaceDetailsRepository? repository;

  @override
  State<PlaceBubbleCard> createState() => _PlaceBubbleCardState();
}

class _PlaceBubbleCardState extends State<PlaceBubbleCard> {
  bool _more = false;

  @override
  void didUpdateWidget(PlaceBubbleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different pin starts folded.
    if (oldWidget.facts.title != widget.facts.title) _more = false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final facts = widget.facts;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        autofocus: true,
        child: Semantics(
          container: true,
          label: 'Place details: ${facts.title}',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(KarumRadius.card),
              border: Border.all(color: palette.line),
              boxShadow: [
                BoxShadow(
                  color: palette.ink.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KarumRadius.card),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, palette),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        KarumSpacing.md,
                        0,
                        KarumSpacing.md,
                        KarumSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _karumFacts(context, palette),
                          const SizedBox(height: KarumSpacing.md),
                          FutureBuilder<PlaceDetails?>(
                            future: widget.details,
                            builder: (context, snapshot) =>
                                _places(context, palette, snapshot),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (facts.onOpenPitch != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KarumSpacing.md,
                        0,
                        KarumSpacing.md,
                        KarumSpacing.md,
                      ),
                      child: FocusRing(
                        borderRadius: BorderRadius.circular(
                          KarumRadius.control,
                        ),
                        child: FilledButton.icon(
                          onPressed: facts.onOpenPitch,
                          icon: const Icon(Icons.route_rounded, size: 18),
                          label: const Text('Open pitch & route'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, KarumPalette palette) {
    final facts = widget.facts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KarumSpacing.md,
        KarumSpacing.sm,
        KarumSpacing.xs,
        KarumSpacing.xs,
      ),
      child: Row(
        children: [
          _Badge(skipped: facts.skipped, rank: facts.rank),
          const SizedBox(width: KarumSpacing.sm),
          Expanded(
            child: Text(
              facts.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          FocusRing(
            borderRadius: BorderRadius.circular(KarumRadius.control),
            child: NamedIconButton(
              label: 'Close place details',
              onPressed: widget.onClose,
              icon: Icons.close_rounded,
              iconSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  /// Karum's own read, from the run payload.
  Widget _karumFacts(BuildContext context, KarumPalette palette) {
    final facts = widget.facts;
    final body = Theme.of(context).textTheme.bodySmall;
    if (facts.skipped) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            facts.reason,
            style: body?.copyWith(
              color: palette.avoid,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (facts.reasonDetail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              facts.reasonDetail,
              style: body?.copyWith(color: palette.mute),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: KarumSpacing.sm,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              facts.score == null
                  ? 'Recommended door ${facts.rank}'
                  : 'Karum score ${facts.score!.round()} · door ${facts.rank}',
              style: body?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (facts.score != null) SourceBadge(source: facts.scoreSource),
          ],
        ),
        if (facts.sharedTags.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Shares: ${facts.sharedTags.take(3).join(', ')}',
            style: body?.copyWith(color: palette.mute),
          ),
        ],
      ],
    );
  }

  /// The Google Places block, in whichever state the lookup is in.
  Widget _places(
    BuildContext context,
    KarumPalette palette,
    AsyncSnapshot<PlaceDetails?> snapshot,
  ) {
    final body = Theme.of(context).textTheme.bodySmall;
    if (snapshot.connectionState != ConnectionState.done) {
      return const _PlacesSkeleton();
    }
    final details = snapshot.data;
    if (snapshot.hasError || details == null || details.isEmpty) {
      return Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: palette.mute),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Place details unavailable',
              style: body?.copyWith(color: palette.mute),
            ),
          ),
        ],
      );
    }

    final today = details.todaysHours();
    final reviews = details.reviews;
    final shownReviews = _more ? reviews : reviews.take(2).toList();
    final hasMore =
        reviews.length > 2 ||
        details.openingHours.isNotEmpty ||
        details.mapsUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (details.photos.isNotEmpty) ...[
          _Photo(
            photo: details.photos.first,
            repository: widget.repository ?? PlaceDetailsRepository.shared,
          ),
          const SizedBox(height: KarumSpacing.sm),
        ],
        Wrap(
          spacing: KarumSpacing.sm,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const SourceBadge(source: 'google_fact'),
            if (details.rating != null) ...[
              Icon(Icons.star_rounded, size: 16, color: palette.investigate),
              Text(
                details.rating!.toStringAsFixed(1),
                style: body?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (details.ratingCount > 0)
                Text(
                  '(${_grouped(details.ratingCount)})',
                  style: body?.copyWith(color: palette.mute),
                ),
            ],
            if (details.priceLevel > 0)
              Text(
                r'$' * details.priceLevel,
                style: body?.copyWith(color: palette.mute),
              ),
            if (details.category.isNotEmpty)
              Text(
                details.category,
                style: body?.copyWith(color: palette.mute),
              ),
          ],
        ),
        if (details.openNow != null) ...[
          const SizedBox(height: KarumSpacing.xs),
          Wrap(
            spacing: KarumSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: details.openNow! ? palette.approach : palette.avoid,
              ),
              Text(
                details.openNow! ? 'Open now' : 'Closed now',
                style: body?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: details.openNow! ? palette.approach : palette.avoid,
                ),
              ),
              if (today != null)
                Text(
                  _afterDay(today),
                  style: body?.copyWith(color: palette.mute),
                ),
            ],
          ),
        ],
        if (details.summary.isNotEmpty) ...[
          const SizedBox(height: KarumSpacing.sm),
          Text(
            details.summary,
            maxLines: _more ? null : 3,
            overflow: _more ? null : TextOverflow.ellipsis,
            style: body?.copyWith(
              color: palette.mute,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: KarumSpacing.sm),
        if (details.address.isNotEmpty)
          FactRow(icon: Icons.place_outlined, text: details.address),
        if (details.phone.isNotEmpty)
          FactRow(
            icon: Icons.phone_outlined,
            text: details.phone,
            onTap: () =>
                openExternal('tel:${details.phone.replaceAll(' ', '')}'),
          ),
        if (details.website.isNotEmpty)
          FactRow(
            icon: Icons.language_rounded,
            text: _host(details.website),
            onTap: () => openExternal(details.website),
          ),
        for (final review in shownReviews) ...[
          const SizedBox(height: KarumSpacing.sm),
          _ReviewTile(review: review),
        ],
        if (_more) ...[
          if (details.openingHours.isNotEmpty) ...[
            const SizedBox(height: KarumSpacing.md),
            Text(
              'Hours',
              style: body?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 2),
            for (final line in details.openingHours)
              Text(line, style: body?.copyWith(color: palette.mute)),
          ],
          if (details.mapsUrl.isNotEmpty) ...[
            const SizedBox(height: KarumSpacing.sm),
            FactRow(
              icon: Icons.map_outlined,
              text: 'Open in Google Maps',
              onTap: () => openExternal(details.mapsUrl),
            ),
          ],
        ],
        if (hasMore)
          LinkButton(
            label: _more ? 'Fewer details' : 'More details',
            onPressed: () => setState(() => _more = !_more),
          ),
      ],
    );
  }

  /// "Monday: 4 PM – 2 AM" becomes "Today: 4 PM – 2 AM".
  static String _afterDay(String line) {
    final i = line.indexOf(': ');
    return 'Today: ${i == -1 ? line : line.substring(i + 2)}';
  }

  static String _host(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    return host.isEmpty ? url : host.replaceFirst('www.', '');
  }

  static String _grouped(int n) {
    final digits = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}

/// The rank disc (numbered, for a recommended door) or the minus disc (for a
/// skipped venue), echoing the map pin the bubble belongs to.
class _Badge extends StatelessWidget {
  const _Badge({required this.skipped, this.rank});

  final bool skipped;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: skipped ? palette.avoid : palette.brand,
      ),
      child: skipped
          ? Icon(Icons.remove_rounded, size: 16, color: palette.surface)
          : Text(
              '$rank',
              style: TextStyle(
                color: palette.onBrand,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1,
              ),
            ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final PlaceReview review;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final byline = [
      if (review.rating != null) '★ ${review.rating!.toStringAsFixed(0)}',
      if (review.author.isNotEmpty) review.author,
      if (review.relativeTime.isNotEmpty) review.relativeTime,
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KarumSpacing.sm),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(KarumRadius.control),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: small,
          ),
          if (byline.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(byline, style: small?.copyWith(color: palette.mute)),
          ],
        ],
      ),
    );
  }
}

/// The venue's first photo, with its photographer credited.
class _Photo extends StatefulWidget {
  const _Photo({required this.photo, required this.repository});

  final PlacePhoto photo;
  final PlaceDetailsRepository repository;

  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> {
  late Future<String> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.repository.photo(widget.photo.name);
  }

  @override
  void didUpdateWidget(_Photo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.name != widget.photo.name) {
      _data = widget.repository.photo(widget.photo.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(KarumRadius.control),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: FutureBuilder<String>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _Skeleton(radius: 0);
                }
                final bytes = _decode(snapshot.data ?? '');
                if (bytes == null) {
                  return ColoredBox(
                    color: palette.paper,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: palette.mute,
                    ),
                  );
                }
                return Semantics(
                  label: 'Photo of this place',
                  image: true,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: palette.paper,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: palette.mute,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.photo.author.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Photo: ${widget.photo.author} · Google',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.mute),
            ),
          ),
      ],
    );
  }

  /// A `data:` URI's bytes, or null when it is empty or malformed.
  static Uint8List? _decode(String dataUri) {
    if (dataUri.isEmpty) return null;
    try {
      return UriData.parse(dataUri).contentAsBytes();
    } on FormatException {
      return null;
    }
  }
}

/// Grey bars in the shape of the Places block, shown while the lookup is out.
class _PlacesSkeleton extends StatelessWidget {
  const _PlacesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading place details',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: _Skeleton(radius: 12)),
          SizedBox(height: KarumSpacing.sm),
          _Skeleton(width: 180, height: 12),
          SizedBox(height: KarumSpacing.xs),
          _Skeleton(width: 240, height: 12),
          SizedBox(height: KarumSpacing.xs),
          _Skeleton(width: 120, height: 12),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({this.width, this.height, this.radius = 4});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.line.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
