import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/src/theme/app_theme.dart';

// A visitor screenshot caught "Try now" (FilledButton) and "New scout"
// (TextButton) with visibly different shapes and heights, because only
// FilledButton carried the brand's control radius and 48 px minimum size.
// These tests pin all three button kinds to the same shape and size, and pin
// the border an unfilled button now carries in its own text colour so it
// never blends into the page (PLAN.md's button-consistency follow-up).
void main() {
  for (final MapEntry(key: name, value: theme) in {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  }.entries) {
    group('$name theme', () {
      OutlinedBorder shapeOf(ButtonStyle? style) =>
          style!.shape!.resolve(<WidgetState>{}) as OutlinedBorder;
      Size minimumSizeOf(ButtonStyle? style) =>
          style!.minimumSize!.resolve(<WidgetState>{})!;

      test('every button kind shares one shape', () {
        final filled = shapeOf(theme.filledButtonTheme.style);
        final outlined = shapeOf(theme.outlinedButtonTheme.style);
        final text = shapeOf(theme.textButtonTheme.style);
        expect(outlined, equals(filled));
        expect(text, equals(filled));
      });

      test('every button kind shares one minimum tap target', () {
        final filled = minimumSizeOf(theme.filledButtonTheme.style);
        final outlined = minimumSizeOf(theme.outlinedButtonTheme.style);
        final text = minimumSizeOf(theme.textButtonTheme.style);
        expect(outlined, equals(filled));
        expect(text, equals(filled));
        expect(filled, const Size(48, 48));
      });

      test(
        'an outlined or text button borders in its own enabled text colour',
        () {
          for (final style in [
            theme.outlinedButtonTheme.style,
            theme.textButtonTheme.style,
          ]) {
            final side = style!.side!.resolve(<WidgetState>{});
            expect(side, isNotNull);
            expect(side!.color, theme.colorScheme.primary);
          }
        },
      );

      test(
        'an outlined or text button borders in its own disabled text colour',
        () {
          for (final style in [
            theme.outlinedButtonTheme.style,
            theme.textButtonTheme.style,
          ]) {
            final side = style!.side!.resolve({WidgetState.disabled});
            expect(side, isNotNull);
            expect(
              side!.color,
              theme.colorScheme.onSurface.withValues(alpha: 0.38),
            );
          }
        },
      );
    });
  }
}
