import 'package:flutter/material.dart';

import 'brand_tokens.dart';

/// Central theme for the Karum client.
///
/// Every colour, type style, and shape here comes from `brand_tokens.dart`, which
/// is transcribed from the official brand guide. Nothing in this file introduces
/// a raw colour or a magic radius: if a value is missing, add the token first and
/// record in `BRAND.md` whether it is official or an implementation decision.
///
/// The app ships both brightnesses because the guide publishes a light and a dark
/// palette, and the guide's own reference page switches on
/// `prefers-color-scheme`. That is also Flutter's default [ThemeMode], so the
/// pair is wired up without forcing a mode.
///
/// [ThemeData.colorScheme] is built from a brand seed and then pinned slot by
/// slot. The seed keeps the slots the guide says nothing about coherent with the
/// brand hue, while every slot the guide *does* specify is overwritten with the
/// official value — a seed alone is how the client previously ended up with an
/// indigo that appears nowhere in the identity.
abstract final class AppTheme {
  /// The light theme: the guide's paper page and ink text.
  static ThemeData light() =>
      _build(palette: KarumPalette.light, brightness: Brightness.light);

  /// The dark theme: the guide's ink-teal dark palette.
  static ThemeData dark() =>
      _build(palette: KarumPalette.dark, brightness: Brightness.dark);

  static ThemeData _build({
    required KarumPalette palette,
    required Brightness brightness,
  }) {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: palette.brand,
          brightness: brightness,
        ).copyWith(
          // The brand itself: links, primary actions, and the mark.
          primary: palette.brand,
          onPrimary: palette.onBrand,
          // Paper is the page; the surface token is what sits on it. Cards and
          // inputs read the surface slots, so the page/card split the guide
          // describes falls out of the scheme rather than out of every widget.
          surface: palette.paper,
          onSurface: palette.ink,
          onSurfaceVariant: palette.mute,
          surfaceContainerLowest: palette.surface,
          surfaceContainerLow: palette.surface,
          // The guide's hairlines, which are decorative only.
          outline: palette.line,
          outlineVariant: palette.line,
          // The Avoid lane is the theme's error colour; every semantic colour in
          // the guide clears AA against paper.
          error: palette.avoid,
          onError: palette.paper,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.paper,
      // Publishes the tokens ColorScheme has no slot for — the four lane
      // accents and the hairline — so widgets never branch on brightness.
      extensions: <ThemeExtension<dynamic>>[palette],
      // Type scale. Slots the guide specifies take the official style; the rest
      // keep the client's existing ramp, which the guide does not contradict.
      textTheme: const TextTheme(
        displaySmall: KarumType.pageTitle,
        headlineMedium: KarumType.resultsHeading,
        titleLarge: KarumType.laneTitle,
        titleMedium: TextStyle(
          fontFamily: KarumFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        bodyLarge: KarumType.body,
        // The guide only fixes the smallest size it allows — 13 px on the
        // limits footer — so secondary body copy stays readable above it.
        bodyMedium: TextStyle(
          fontFamily: KarumFonts.body,
          fontSize: 14,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontFamily: KarumFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelSmall: KarumType.badge,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
        elevation: KarumElevation.flat,
        scrolledUnderElevation: KarumElevation.flat,
        centerTitle: false,
      ),
      // Flat, hairline-separated cards, as the guide draws its panels.
      cardTheme: CardThemeData(
        elevation: KarumElevation.flat,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KarumRadius.card),
          side: const BorderSide(
            color: KarumColors.line,
            width: KarumElevation.hairline,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KarumRadius.pill),
          side: BorderSide(color: palette.line),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: KarumElevation.hairline,
        space: KarumSpacing.lg,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KarumRadius.control),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KarumRadius.control),
          borderSide: BorderSide(color: palette.line),
        ),
        // The guide's focus treatment is a ring of brand colour; Flutter has no
        // outline-offset, so the documented 3 px weight is carried on the
        // focused border and the full keyboard treatment follows in §30.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KarumRadius.control),
          borderSide: BorderSide(
            color: palette.brand,
            width: KarumBrand.focusRingWidth,
          ),
        ),
      ),
      // One shape and tap-target size for every button kind. Filled,
      // outlined, and text buttons used to agree on neither: only
      // FilledButton carried `KarumRadius.control` and a 48 px minimum, so an
      // unthemed OutlinedButton or TextButton fell back to Material 3's own
      // defaults (a fully rounded stadium shape and a 40 px minimum) and sat
      // visibly out of step beside a themed one on the same row — "Try now"
      // next to "New scout" is the pair that surfaced it. `control` was
      // already documented as the radius for "inputs, buttons, and banners"
      // (`KarumRadius.control`); only the FilledButton theme had ever
      // actually used it.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: _buttonMinimumSize,
          shape: _buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: _buttonMinimumSize,
          shape: _buttonShape,
        ).copyWith(side: _buttonBorderMatchingText(scheme)),
      ),
      // A TextButton has no fill and, unstyled, no border either — against a
      // dark page it reads as a label, not a control. The guide draws no
      // "ghost button," so this is an implementation decision: give it a
      // border in the same colour as its own text, at both the enabled and
      // the disabled opacity, so every button on the page is legible as a
      // button before it is pressed (BRAND.md records this as implementation).
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: _buttonMinimumSize,
          shape: _buttonShape,
        ).copyWith(side: _buttonBorderMatchingText(scheme)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// The one corner radius every button kind shares — implementation, not
  /// brand-specified (see `BRAND.md`'s "Official, derived, implementation").
  static final RoundedRectangleBorder _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(KarumRadius.control),
  );

  /// The one minimum tap target every button kind shares.
  static const Size _buttonMinimumSize = Size(48, 48);

  /// A border that always matches the button's own text colour, at the same
  /// enabled/disabled opacity [TextButton] and [OutlinedButton] already use
  /// for their foreground — so a button with no fill still reads as a button
  /// against the page instead of as a floating label.
  static WidgetStateProperty<BorderSide> _buttonBorderMatchingText(
    ColorScheme scheme,
  ) => WidgetStateProperty.resolveWith((states) {
    final color = states.contains(WidgetState.disabled)
        ? scheme.onSurface.withValues(alpha: 0.38)
        : scheme.primary;
    return BorderSide(color: color);
  });
}
