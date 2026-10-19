import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karum/src/theme/app_theme.dart';
import 'package:karum/src/theme/brand_tokens.dart';
import 'package:karum/src/widgets/karum_logo.dart';

/// The asset a drawn [KarumLogo] resolved to.
String _assetOf(WidgetTester tester) {
  final SvgPicture picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
  return (picture.bytesLoader as SvgAssetLoader).assetName;
}

/// The box a drawn [KarumLogo] asked for.
Size _sizeOf(WidgetTester tester) {
  final SvgPicture picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
  return Size(picture.width ?? 0, picture.height ?? 0);
}

/// Hosts a logo inside a themed app at a fixed width, so the widget's own
/// 480 px collapse rule can be exercised without a real window.
Widget _host(Widget logo, {required double width, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: width, child: logo),
        ),
      ),
    ),
  );
}

void main() {
  group('KarumLogo', () {
    testWidgets('draws the official file that matches the surface', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const KarumLogo(), width: 600));
      await tester.pumpAndSettle();
      expect(_assetOf(tester), KarumAssets.lockupLight);

      await tester.pumpWidget(
        _host(const KarumLogo(), width: 600, theme: AppTheme.dark()),
      );
      await tester.pumpAndSettle();
      expect(_assetOf(tester), KarumAssets.lockupDark);

      // On the brand teal itself, or over imagery, the one-colour variant is the
      // only one the guide allows.
      await tester.pumpWidget(
        _host(const KarumLogo(style: KarumLogoStyle.reversed), width: 600),
      );
      await tester.pumpAndSettle();
      expect(_assetOf(tester), KarumAssets.lockupWhite);
    });

    testWidgets('collapses to the mark alone below 480 px', (tester) async {
      await tester.pumpWidget(_host(const KarumLogo(), width: 320));
      await tester.pumpAndSettle();
      expect(_assetOf(tester), KarumAssets.markLight);

      await tester.pumpWidget(_host(const KarumLogo(), width: 480));
      await tester.pumpAndSettle();
      expect(_assetOf(tester), KarumAssets.lockupLight);

      // The 480 px rule belongs to the header. A caller that needs the lockup
      // kept — the hero does, so the mark is never shown without the wordmark —
      // can switch it off.
      await tester.pumpWidget(
        _host(const KarumLogo(autoCollapse: false), width: 320),
      );
      await tester.pumpAndSettle();
      expect(_assetOf(tester), KarumAssets.lockupLight);
    });

    testWidgets('never draws below the documented minimum size', (
      tester,
    ) async {
      // The guide's floor for the mark is 16 px.
      await tester.pumpWidget(
        _host(
          const KarumLogo(variant: KarumLogoVariant.mark, height: 8),
          width: 600,
        ),
      );
      await tester.pumpAndSettle();
      expect(_sizeOf(tester).height, KarumBrand.minMarkSize);

      // The lockup's floor is 72 px wide, whatever height that works out to.
      await tester.pumpWidget(_host(const KarumLogo(height: 4), width: 600));
      await tester.pumpAndSettle();
      expect(_sizeOf(tester).width, closeTo(KarumBrand.minLockupWidth, 0.01));
    });

    testWidgets('keeps the artwork on its own aspect ratio', (tester) async {
      await tester.pumpWidget(_host(const KarumLogo(height: 32), width: 600));
      await tester.pumpAndSettle();
      final Size lockup = _sizeOf(tester);
      expect(lockup.height, 32);
      expect(lockup.width, 32 * KarumBrand.lockupAspectRatio);

      await tester.pumpWidget(
        _host(
          const KarumLogo(variant: KarumLogoVariant.mark, height: 32),
          width: 600,
        ),
      );
      await tester.pumpAndSettle();
      final Size mark = _sizeOf(tester);
      expect(mark, const Size(32, 32));
    });
  });

  testWidgets('every bundled brand file is really in the asset bundle', (
    tester,
  ) async {
    // Each bundled file is the *right* variant, not just present: the light and
    // dark pairs differ only by their ink, so checking for the ink catches a
    // mis-wired swap that a bare "file exists" check would not.
    const Map<String, String> inkOf = <String, String>{
      KarumAssets.markLight: '#0F4C4A',
      KarumAssets.markDark: '#6FC4BA',
      KarumAssets.markWhite: '#FFFFFF',
      KarumAssets.lockupLight: '#0F4C4A',
      KarumAssets.lockupDark: '#6FC4BA',
      KarumAssets.lockupWhite: '#FFFFFF',
    };

    late final Map<String, String> bodies;
    await tester.runAsync(() async {
      final List<String> loaded = await Future.wait(
        inkOf.keys.map(rootBundle.loadString),
      );
      bodies = Map<String, String>.fromIterables(inkOf.keys, loaded);
    });

    expect(bodies.keys, hasLength(inkOf.length));
    for (final MapEntry<String, String> entry in bodies.entries) {
      expect(entry.value, contains('<svg'));
      expect(entry.value, contains(inkOf[entry.key]!));
    }
  });
}
