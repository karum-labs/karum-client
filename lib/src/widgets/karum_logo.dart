import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/brand_tokens.dart';

/// Which piece of official artwork [KarumLogo] draws.
enum KarumLogoVariant {
  /// Mark plus wordmark. The guide's first choice wherever the width allows it,
  /// because "always show it beside the wordmark in the hero and cards" is how
  /// the mark gets recognised at all.
  lockup,

  /// The mark on its own — for headers narrower than
  /// [KarumLayout.markOnlyBelow], and for square contexts such as an avatar.
  mark,
}

/// Which official colour variant to draw, chosen by the surface behind it.
enum KarumLogoStyle {
  /// For paper and other light surfaces: a #0F4C4A mark.
  light,

  /// For the dark palette: a #6FC4BA mark.
  dark,

  /// One-colour reversed, white. The variant to reach for on the brand teal
  /// itself or over imagery, where neither [light] nor [dark] clears contrast.
  reversed;

  /// The style that matches [brightness].
  static KarumLogoStyle forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Draws the official Karum artwork.
///
/// The files are the brand kit's own SVGs, drawn unmodified through
/// `flutter_svg`: the lockup keeps its outlined wordmark, the mark keeps its
/// 64-unit construction, and neither is ever stretched, cropped, or recoloured.
/// Colour comes from picking the right variant, which is why [style] exists
/// rather than a tint.
///
/// Sizes follow the guide's *App header* row — 24 or 32 px tall, dropping the
/// wordmark below 480 px — and the artwork is clamped up to its documented
/// minimum size rather than drawn off-spec.
class KarumLogo extends StatelessWidget {
  /// Creates a logo.
  const KarumLogo({
    super.key,
    this.variant = KarumLogoVariant.lockup,
    this.style,
    this.height = KarumBrand.headerHeight,
    this.autoCollapse = true,
    this.semanticLabel = 'Karum',
  });

  /// The artwork to draw.
  final KarumLogoVariant variant;

  /// The colour variant, or null to follow the ambient theme's brightness.
  final KarumLogoStyle? style;

  /// Height in logical pixels. The width follows the artwork's own aspect ratio.
  final double height;

  /// Whether to fall back to the mark alone below
  /// [KarumLayout.markOnlyBelow], as the guide does for the app header.
  final bool autoCollapse;

  /// Alternative text. The lockup is a wordmark, so "Karum" is meaningful; pass
  /// null when the logo is purely decorative and the surrounding copy already
  /// names the product.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KarumLogoStyle resolvedStyle =
        style ?? KarumLogoStyle.forBrightness(Theme.of(context).brightness);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Unbounded width — a row, for instance — counts as room for the lockup.
        final bool collapse =
            autoCollapse && constraints.maxWidth < KarumLayout.markOnlyBelow;
        final KarumLogoVariant drawn = collapse
            ? KarumLogoVariant.mark
            : variant;

        // The guide's minimums: 16 px for the mark, 72 px wide for the lockup.
        final double minimum = drawn == KarumLogoVariant.mark
            ? KarumBrand.minMarkSize
            : KarumBrand.minLockupWidth / KarumBrand.lockupAspectRatio;
        final double drawnHeight = math.max(height, minimum);

        return SvgPicture.asset(
          _asset(drawn, resolvedStyle),
          width: drawnHeight * _aspectRatio(drawn),
          height: drawnHeight,
          fit: BoxFit.contain,
          semanticsLabel: semanticLabel,
        );
      },
    );
  }

  /// The official file for [variant] in [style]. The artwork is not tinted, so
  /// every combination names a real file in the kit.
  static String _asset(KarumLogoVariant variant, KarumLogoStyle style) {
    return switch ((variant, style)) {
      (KarumLogoVariant.lockup, KarumLogoStyle.light) =>
        KarumAssets.lockupLight,
      (KarumLogoVariant.lockup, KarumLogoStyle.dark) => KarumAssets.lockupDark,
      (KarumLogoVariant.lockup, KarumLogoStyle.reversed) =>
        KarumAssets.lockupWhite,
      (KarumLogoVariant.mark, KarumLogoStyle.light) => KarumAssets.markLight,
      (KarumLogoVariant.mark, KarumLogoStyle.dark) => KarumAssets.markDark,
      (KarumLogoVariant.mark, KarumLogoStyle.reversed) => KarumAssets.markWhite,
    };
  }

  static double _aspectRatio(KarumLogoVariant variant) =>
      variant == KarumLogoVariant.mark
      ? KarumBrand.markAspectRatio
      : KarumBrand.lockupAspectRatio;
}
