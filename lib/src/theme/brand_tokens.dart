/// Karum design tokens.
///
/// Every value here is transcribed from the official **Karum brand guide**
/// (spec v2.0). Nothing in `lib/` should carry a raw colour, font size, radius,
/// or logo size: if a value is missing, add a token first.
///
/// Each token is tagged in its doc comment:
///
/// * **official** — an explicit value published in the brand guide.
/// * **derived** — computed from an official value (an em-based letter spacing
///   resolved to logical pixels, for example).
/// * **implementation** — a value the guide does not define, chosen here so the
///   app has something to render. Never describe these as brand specifications.
///
/// The inventory, the source of each value, and what is still missing from the
/// kit are in `BRAND.md` at the repository root.
library;

import 'package:flutter/material.dart';

/// The official Karum palette.
///
/// The guide publishes one value per token per theme, so the light and dark
/// pairs are kept side by side: a reviewer can diff this against the guide's
/// colour table in one pass. The contrast ratios in the doc comments are the
/// ones the guide publishes (each colour as text against that theme's paper),
/// not figures computed here.
abstract final class KarumColors {
  // ---------------------------------------------------------------- surfaces

  /// **official** — page background. "Paper is a cool, slightly green off-white,
  /// not cream." About 60% of a screen.
  static const Color paper = Color(0xFFF4F5F1);

  /// **official** — page background, dark theme.
  static const Color paperDark = Color(0xFF0D1514);

  /// **official** — panel and card surface, from the guide's own stylesheet.
  static const Color surface = Color(0xFFFFFFFF);

  /// **official** — panel and card surface, dark theme.
  static const Color surfaceDark = Color(0xFF141E1C);

  // -------------------------------------------------------------------- text

  /// **official** — text. 15.08:1 on paper, 15.52:1 on the dark paper.
  static const Color ink = Color(0xFF16211F);

  /// **official** — text, dark theme.
  static const Color inkDark = Color(0xFFE9ECE6);

  /// **official** — secondary text, and the Excluded lane. 5.94:1 / 7.29:1.
  static const Color mute = Color(0xFF56605D);

  /// **official** — secondary text, dark theme.
  static const Color muteDark = Color(0xFF9AA5A1);

  // ------------------------------------------------------------------- brand

  /// **official** — "ink-teal is the brand colour": the mark, links, and the
  /// LIVE badge. 8.91:1 on paper, 9.06:1 on the dark paper.
  static const Color brand = Color(0xFF0F4C4A);

  /// **official** — the brand colour, dark theme.
  static const Color brandDark = Color(0xFF6FC4BA);

  /// **official** — the text colour the guide pairs with [brand]: the LIVE badge
  /// is drawn as paper on brand. (The guide also records plain white on brand
  /// teal at 9.75:1.)
  static const Color onBrand = paper;

  /// **official** — the text colour the guide pairs with [brandDark].
  static const Color onBrandDark = paperDark;

  // ------------------------------------------------------------------- lanes

  /// **official** — Approach lane. 5.93:1 / 8.25:1.
  ///
  /// The lane colours "double as brand accents but never carry meaning alone",
  /// so every one of them is always paired with its own shape.
  static const Color approach = Color(0xFF1B6B45);

  /// **official** — Approach lane, dark theme.
  static const Color approachDark = Color(0xFF5CC08A);

  /// **official** — Investigate lane. 5.78:1 / 8.28:1.
  static const Color investigate = Color(0xFF8A5300);

  /// **official** — Investigate lane, dark theme.
  static const Color investigateDark = Color(0xFFE0A23A);

  /// **official** — Avoid lane. 6.77:1 / 7.65:1.
  static const Color avoid = Color(0xFF9E2B2B);

  /// **official** — Avoid lane, dark theme.
  static const Color avoidDark = Color(0xFFF08A84);

  /// **official** — Excluded lane. The guide gives it [mute]'s value in both
  /// themes.
  static const Color excluded = mute;

  /// **official** — Excluded lane, dark theme.
  static const Color excludedDark = muteDark;

  // ------------------------------------------------------------------- lines

  /// **official** — hairlines and dividers. The guide marks these decorative
  /// only: never let a line carry meaning, and never count one towards a
  /// contrast minimum.
  static const Color line = Color(0xFFD8DCD5);

  /// **official** — hairlines and dividers, dark theme.
  static const Color lineDark = Color(0xFF2A3835);
}

/// The three official typefaces.
///
/// **The font files are not supplied with the brand guide**, and they are
/// deliberately not vendored here — see `BRAND.md` § Missing from the kit.
/// Until the SIL Open Font License files are added to the `fonts:` section of
/// `pubspec.yaml`, a family named here resolves to the platform default;
/// nothing else has to change when they land.
abstract final class KarumFonts {
  /// **official** — the wordmark and every heading. Bricolage Grotesque, loaded
  /// by the guide at weights 600 and 700.
  static const String display = 'Bricolage Grotesque';

  /// **official** — body copy, reasons, and the limits footer. IBM Plex Sans.
  static const String body = 'IBM Plex Sans';

  /// **official** — scores and the evidence drawer. IBM Plex Mono. "Plex's
  /// numerals are clear and tabular, which matters for scores and lifts."
  static const String mono = 'IBM Plex Mono';
}

/// The official type scale, from the guide's *Typography* table.
///
/// Sizes, weights, and line heights are the table's values verbatim. Tracking is
/// **derived**: the guide gives headings as −0.01em and the wordmark as −0.02em,
/// which is resolved here to logical pixels at each size.
///
/// These styles are named for what the guide uses them for, not for a Material
/// role, so a screen can ask for the evidence-drawer style without working out
/// which `TextTheme` slot it fell into. [AppTheme] additionally maps the closest
/// Material slots onto them.
abstract final class KarumType {
  /// **official** — the guide's `h1`, "Wordmark, headings": Bricolage Grotesque
  /// 700 with −0.01em tracking and a 1.15 line height. The guide clamps the size
  /// to `clamp(34px, 6vw, 52px)`; the app uses the 34 px lower bound, which is
  /// also the size the client's page titles already were.
  static const TextStyle pageTitle = TextStyle(
    fontFamily: KarumFonts.display,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.34,
  );

  /// **official** — "Results heading": 28 / 700 / 1.15.
  static const TextStyle resultsHeading = TextStyle(
    fontFamily: KarumFonts.display,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.28,
  );

  /// **official** — "Lane title": 18 / 700 / 1.2.
  static const TextStyle laneTitle = TextStyle(
    fontFamily: KarumFonts.display,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.18,
  );

  /// **official** — "Body, reasons": IBM Plex Sans, 16 / 400 / 1.6.
  static const TextStyle body = TextStyle(
    fontFamily: KarumFonts.body,
    fontSize: 16,
    height: 1.6,
  );

  /// **official** — "Score label": IBM Plex Mono, 14 / 500 / 1.3, tabular.
  static const TextStyle scoreLabel = TextStyle(
    fontFamily: KarumFonts.mono,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// **official** — "Evidence drawer": IBM Plex Mono, 13 / 400 / 1.5.
  static const TextStyle evidence = TextStyle(
    fontFamily: KarumFonts.mono,
    fontSize: 13,
    height: 1.5,
  );

  /// **official** — "Limits footer": IBM Plex Sans, 13 / 400 / 1.5, and the
  /// guide is explicit that it never goes smaller.
  static const TextStyle limitsFooter = TextStyle(
    fontFamily: KarumFonts.body,
    fontSize: 13,
    height: 1.5,
  );

  /// **official** — the data-mode badge label: IBM Plex Mono 500 at 12 px with
  /// +0.04em tracking. Documents the LIVE / CACHED / RECORDED / FIXTURE badges.
  static const TextStyle badge = TextStyle(
    fontFamily: KarumFonts.mono,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.48,
  );

  /// **official** — the wordmark "typeset in Bricolage Grotesque 700 with
  /// tightened tracking": 34 / 700 / 1 with −0.02em.
  ///
  /// Only needed if the wordmark is ever set as live text. The shipped lockup
  /// has it outlined as paths, so nothing renders this today.
  static const TextStyle wordmark = TextStyle(
    fontFamily: KarumFonts.display,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: -0.68,
  );
}

/// Spacing scale — **derived**.
///
/// The guide publishes no spacing scale, so this is inferred from its own
/// stylesheet, which is the only place it commits to repeated distances: a 40 px
/// page inset, 28 px panel padding, 16 px card padding, and 10 / 14 px lane rows.
/// The ramp is the values those use, rounded onto a 4 px grid.
abstract final class KarumSpacing {
  /// 4 px — hairline gaps inside a chip or a bar.
  static const double xs = 4;

  /// 8 px
  static const double sm = 8;

  /// 12 px — the gap between a mark and its wordmark.
  static const double md = 12;

  /// 16 px — card and panel inner padding.
  static const double lg = 16;

  /// 24 px — between sibling blocks.
  static const double xl = 24;

  /// 28 px — panel padding, the guide's widest inner padding.
  static const double xl2 = 28;

  /// 40 px — the page inset.
  static const double page = 40;
}

/// Layout — **derived** from the guide's own stylesheet, apart from the
/// breakpoint, which is **official**.
abstract final class KarumLayout {
  /// 880 px — the guide sets `max-width: 880px` on its content column.
  static const double contentMaxWidth = 880;

  /// 480 px — **official**: the app header "drops to a mark-only treatment below
  /// 480 px". This is the one breakpoint the guide specifies.
  static const double markOnlyBelow = 480;
}

/// Corner radii — **implementation**.
///
/// The guide publishes no radii. These are the values the client already used,
/// kept deliberately so that a brand pass does not restyle unrelated
/// components; panels read as flat rectangles separated by a hairline.
abstract final class KarumRadius {
  /// 14 — cards.
  static const double card = 14;

  /// 12 — inputs, buttons, and banners.
  static const double control = 12;

  /// A fully rounded pill, for chips.
  static const double pill = 999;
}

/// Elevation — **implementation**.
///
/// The guide's surfaces are flat: a 1 px hairline in [KarumColors.line] does all
/// the separating, so every elevation is zero and a shadow is never used to
/// carry hierarchy.
abstract final class KarumElevation {
  /// 0 — flat. The only elevation the brand uses.
  static const double flat = 0;

  /// 1 px — the hairline that replaces a shadow.
  static const double hairline = 1;
}

/// Documented brand rules that are numbers rather than colours — all
/// **official**.
///
/// These constrain how the artwork in [KarumAssets] may be drawn.
abstract final class KarumBrand {
  /// **official** — construction: a 64-unit grid with a 7-unit miter stroke,
  /// posts at x 13 and x 51, the top bar at y 13, and a dot of radius 6.5
  /// centred at (32, 40). Recorded so the artwork can be re-derived, never
  /// redrawn at runtime.
  static const double gridUnits = 64;

  /// **official** — clear space is one dot diameter — 13 units of the 64-unit
  /// grid — on every side of the artwork.
  static const double clearSpaceUnits = 13;

  /// **official** — clear space as a fraction of the artwork's own size.
  static const double clearSpaceFraction = clearSpaceUnits / gridUnits;

  /// **official** — minimum size for the mark on its own: 16 px.
  static const double minMarkSize = 16;

  /// **official** — minimum width for the lockup: 72 px.
  static const double minLockupWidth = 72;

  /// **official** — the mark is square, on a 64-unit grid.
  static const double markAspectRatio = 1;

  /// **official** — the lockup is 213 × 64, mark plus outlined wordmark.
  static const double lockupAspectRatio = 213 / 64;

  /// **official** — the app header is 24 or 32 px tall.
  static const double headerHeight = 32;

  /// **official** — the compact app header height.
  static const double headerHeightCompact = 24;

  /// **derived** — the size the guide's own reference page draws its hero at: a
  /// 56 px mark beside a 34 px wordmark, which is [KarumType.pageTitle]'s size.
  /// Keeps the landing screen's product name at the optical weight it had as
  /// 34 px text.
  static const double heroLockup = 56;

  /// **official** — the focus ring is 3 px of brand colour, offset 2 px from the
  /// control. Flutter has no `outline-offset`, so the offset is recorded here and
  /// the focus styling that can express it lands with §30's keyboard audit.
  static const double focusRingWidth = 3;

  /// **official** — an icon is drawn on a 24-unit grid with a 2 to 2.5 unit
  /// stroke, square caps, and miter joins.
  static const double iconGrid = 24;

  /// **official** — the narrowest icon stroke.
  static const double iconStrokeMin = 2;

  /// **official** — the widest icon stroke.
  static const double iconStrokeMax = 2.5;

  /// **official** — the source dot, radius 4 on the 24-unit icon grid. It marks
  /// the source of a number wherever a score is shown.
  static const double sourceDotRadius = 4;
}

/// The official artwork the app renders.
///
/// Only these variants are declared under `assets:` in `pubspec.yaml`, so only
/// these are shipped in the web build. The remainder of the kit — the
/// one-colour and reversed marks, the README banners, the GitHub org avatar, the
/// Devpost thumbnail — stays in `assets/brand/` for the places that need it
/// without being weighed into the bundle. See `BRAND.md`.
abstract final class KarumAssets {
  /// Official mark, #0F4C4A, for paper and other light surfaces.
  static const String markLight = 'assets/brand/mark/karum-mark.svg';

  /// Official mark, #6FC4BA, for the dark palette.
  static const String markDark = 'assets/brand/mark/karum-mark-dark.svg';

  /// Official one-colour reversed mark, white. The variant to reach for on the
  /// brand teal itself or over imagery, where neither [markLight] nor
  /// [markDark] clears contrast.
  static const String markWhite = 'assets/brand/mark/karum-mark-white.svg';

  /// Official lockup, #0F4C4A mark with an #16211F wordmark, for light
  /// surfaces. The first choice wherever the width allows it.
  static const String lockupLight =
      'assets/brand/lockup/karum-lockup-light.svg';

  /// Official lockup for the dark palette: #6FC4BA mark, #E9ECE6 wordmark.
  static const String lockupDark = 'assets/brand/lockup/karum-lockup-dark.svg';

  /// Official one-colour reversed lockup, white.
  static const String lockupWhite =
      'assets/brand/lockup/karum-lockup-white.svg';

  /// Every file declared under `assets:` in `pubspec.yaml`.
  ///
  /// A test loads each one, so a renamed or undeclared file fails the suite
  /// rather than showing up later as a blank header.
  static const List<String> bundled = <String>[
    markLight,
    markDark,
    markWhite,
    lockupLight,
    lockupDark,
    lockupWhite,
  ];
}

/// The brand palette for the active brightness, published as a
/// [ThemeExtension].
///
/// [ColorScheme] has no slot for the four lane accents or for the decorative
/// hairline, so they would otherwise have to be selected with a `brightness`
/// branch at every call site. Publishing them here means a widget reads the
/// brand the same way it reads `Theme.of(context).colorScheme`, and the palette
/// cross-fades for free when the brightness changes because [lerp] is
/// implemented.
@immutable
class KarumPalette extends ThemeExtension<KarumPalette> {
  /// Creates a palette. Every field is a token from [KarumColors].
  const KarumPalette({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.mute,
    required this.brand,
    required this.onBrand,
    required this.approach,
    required this.investigate,
    required this.avoid,
    required this.excluded,
    required this.line,
  });

  /// The official light palette.
  static const KarumPalette light = KarumPalette(
    paper: KarumColors.paper,
    surface: KarumColors.surface,
    ink: KarumColors.ink,
    mute: KarumColors.mute,
    brand: KarumColors.brand,
    onBrand: KarumColors.onBrand,
    approach: KarumColors.approach,
    investigate: KarumColors.investigate,
    avoid: KarumColors.avoid,
    excluded: KarumColors.excluded,
    line: KarumColors.line,
  );

  /// The official dark palette.
  static const KarumPalette dark = KarumPalette(
    paper: KarumColors.paperDark,
    surface: KarumColors.surfaceDark,
    ink: KarumColors.inkDark,
    mute: KarumColors.muteDark,
    brand: KarumColors.brandDark,
    onBrand: KarumColors.onBrandDark,
    approach: KarumColors.approachDark,
    investigate: KarumColors.investigateDark,
    avoid: KarumColors.avoidDark,
    excluded: KarumColors.excludedDark,
    line: KarumColors.lineDark,
  );

  /// The page background.
  final Color paper;

  /// A panel or card sitting on [paper].
  final Color surface;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color mute;

  /// The brand colour: the mark, links, and the LIVE badge.
  final Color brand;

  /// Text drawn on [brand].
  final Color onBrand;

  /// Approach lane.
  final Color approach;

  /// Investigate lane.
  final Color investigate;

  /// Avoid lane.
  final Color avoid;

  /// Excluded lane.
  final Color excluded;

  /// Decorative hairlines. Never meaning-bearing.
  final Color line;

  /// The palette for the ambient theme.
  ///
  /// Falls back to the brightness-matched palette when no [KarumPalette] is
  /// registered, so a widget still renders correctly inside a bare [MaterialApp]
  /// — which is how the widget tests build it.
  static KarumPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<KarumPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  KarumPalette copyWith({
    Color? paper,
    Color? surface,
    Color? ink,
    Color? mute,
    Color? brand,
    Color? onBrand,
    Color? approach,
    Color? investigate,
    Color? avoid,
    Color? excluded,
    Color? line,
  }) {
    return KarumPalette(
      paper: paper ?? this.paper,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      mute: mute ?? this.mute,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      approach: approach ?? this.approach,
      investigate: investigate ?? this.investigate,
      avoid: avoid ?? this.avoid,
      excluded: excluded ?? this.excluded,
      line: line ?? this.line,
    );
  }

  @override
  KarumPalette lerp(covariant KarumPalette? other, double t) {
    if (other == null) {
      return this;
    }
    return KarumPalette(
      paper: Color.lerp(paper, other.paper, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mute: Color.lerp(mute, other.mute, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      approach: Color.lerp(approach, other.approach, t)!,
      investigate: Color.lerp(investigate, other.investigate, t)!,
      avoid: Color.lerp(avoid, other.avoid, t)!,
      excluded: Color.lerp(excluded, other.excluded, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}
