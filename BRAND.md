# Brand

Karum's visual system comes from the **official brand guide** (spec v2.0) and the brand asset archive, both supplied to the team on 19 Oct 2026. This repo is their home: the artwork lives in [`assets/brand/`](assets/brand) and [`web/`](web), the values the app renders live in [`lib/src/theme/brand_tokens.dart`](lib/src/theme/brand_tokens.dart), and this file records where each value came from, how to use it, and what the kit is still missing.

Three labels are used throughout the code and this file:

| Label | Meaning |
| --- | --- |
| **official** | An explicit value or rule published in the brand guide. |
| **derived** | Computed from official values without changing them — an em-based tracking resolved to logical pixels, for example. |
| **implementation** | A choice the guide does not define, made here so the app has something to render. Never a brand specification. |

Every token in `brand_tokens.dart` carries its label in the doc comment beside it.

## The asset kit

**`assets/brand/mark/` — the mark alone.** `karum-mark.svg` (light, #0F4C4A), `karum-mark-dark.svg` (#6FC4BA), `karum-mark-white.svg` (one-colour white on transparent) with a PNG twin, `karum-mark-reversed.svg` (white on a black tile), and `karum-mark-onecolour-black.svg` (single-colour black on transparent). For square slots: the app header below 480 px, avatars, favicons.

**`assets/brand/lockup/` — mark plus outlined wordmark.** Light, dark, white, and one-colour black SVGs, plus light, dark, and white PNG renders. The guide's first choice wherever the width allows; `karum-lockup-light.svg` is deliberately mixed — a teal mark with an ink wordmark.

**`assets/brand/social/` — outward-facing cards.** The GitHub org avatar (500), the repo social preview (1280×640), the README banner (1600×400), the Devpost thumbnail (1200×800), and the og share card (1200×630). Avatar, preview, banner, and thumbnail come as SVG plus a raster PNG in light and dark pairs; the og card is the exception — its single PNG lives in `web/`, its only consumer (see below), beside its light and dark SVGs here.

**`web/` — what the browser loads from the site root.** Flutter copies this directory to the build output root, so these are referenced bare, with no path prefix:

- `favicon-adaptive.svg` — carries both mark colours and switches on `prefers-color-scheme`; listed first in `index.html`.
- `favicon.png` / `favicon-dark.png` — the 32 px fallback for browsers that do not take an SVG icon.
- `apple-touch-icon-180.png` / `apple-touch-icon-180-dark.png`.
- `og-share-card-1200x630.png` — referenced by `index.html` with the absolute Firebase Hosting URL the Open Graph spec wants.

Only the six SVGs `KarumLogo` can draw are declared under `assets:` in `pubspec.yaml`, so only they are bundled into the app; the social cards are repo furniture and stay out of the web build.

## Using the artwork

Draw it through `KarumLogo` in [`lib/src/widgets/karum_logo.dart`](lib/src/widgets/karum_logo.dart):

```dart
const KarumLogo(height: KarumBrand.headerHeight)                     // header, follows the theme
const KarumLogo(height: KarumBrand.heroLockup, autoCollapse: false)  // hero, always the lockup
KarumLogo(variant: KarumLogoVariant.mark, style: KarumLogoStyle.reversed) // on brand teal or imagery
```

- `variant` picks the lockup or the mark; `style` picks the light / dark / reversed file, or follows the ambient brightness when omitted; `autoCollapse` applies the guide's header rule.
- Pass `semanticLabel: null` when the logo is purely decorative and the surrounding copy already names the product.

Rules carried over from the guide, in code as `KarumBrand`:

- **Never stretch, crop, or recolour the artwork.** Pick the file that matches the surface; colour comes from the variant, which is why there is no tint API.
- Clear space is 13 of the mark's 64 units on every side.
- Minimum sizes are 16 px for the mark and 72 px wide for the lockup; the widget clamps up to them rather than drawing off-spec.
- The app header is 24 or 32 px tall and drops to the mark alone below 480 px — the one breakpoint the guide specifies.
- Icons are drawn on a 24-unit grid with 2–2.5 unit strokes, square caps, and miter joins; the focus ring is 3 px of brand colour with a 2 px offset.
- The lane colours double as accents but never carry meaning alone; every lane is paired with its own shape or label.

## Tokens

| Where | What |
| --- | --- |
| [`lib/src/theme/brand_tokens.dart`](lib/src/theme/brand_tokens.dart) | Every brand value: `KarumColors` (the light/dark pairs with the guide's published contrast ratios), `KarumFonts` and `KarumType` (the named type styles), `KarumSpacing`, `KarumLayout`, `KarumRadius`, `KarumElevation`, `KarumBrand` (the numeric logo rules above), `KarumAssets` (the bundled files), and `KarumPalette` (the theme extension). |
| [`lib/src/theme/app_theme.dart`](lib/src/theme/app_theme.dart) | `AppTheme.light()` and `AppTheme.dark()`, built from the tokens: a brand-seeded `ColorScheme` pinned slot by slot to the official pairs, the palette extension, and the type scale mapped onto Material slots. |
| [`lib/main.dart`](lib/main.dart) | Wires `theme` and `darkTheme`, so the app follows the system brightness — the same `prefers-color-scheme` behaviour the guide's own page uses. |

How to consume them:

- In widgets, read `KarumPalette.of(context)` rather than `KarumColors` directly, so the brightness-correct value is selected for free (the palette cross-fades when the brightness changes).
- Named type styles live in `KarumType` (`pageTitle`, `resultsHeading`, `laneTitle`, `body`, `scoreLabel`, `evidence`, `limitsFooter`, `badge`, `wordmark`); `AppTheme` maps the closest Material slots onto them for widgets that use `theme.textTheme`.
- No widget carries a raw colour, size, or radius. If a value is missing, add a token first.

## Official, derived, implementation

- **Official:** the colour pairs and their contrast ratios, the three type families and the whole type table (sizes, weights, line heights, tracking), mark construction, clear space, minimum sizes, the 480 px header breakpoint, the icon grid, the focus ring, and the lane system.
- **Derived:** tracking resolved from em to logical pixels; the spacing ramp, built from distances in the guide's own stylesheet and rounded onto a 4 px grid; the 880 px content width and 40 px page inset from the guide's page CSS; the 56 px hero lockup, which matches the guide's reference-page proportions.
- **Implementation:** the corner radii (14 / 12 / pill) and the flat-plus-hairline elevation — the guide is silent, so the client's existing values were kept deliberately rather than restyling unrelated components; the mode-banner colour mapping (live → brand, fixture → investigate, degraded → avoid), which the guide does not make; anything labelled implementation in the code.

## What was replaced

- The default Flutter web icons (`web/icons/Icon-192.png`, `Icon-512.png`, and the two maskables) are deleted; `index.html` and `manifest.json` now point at the kit's favicons and touch icons, and the manifest declares only sizes that exist.
- The scaffold's blue Material seed and text-only product name are gone: the theme is built from the tokens, and the header and hero draw the official lockup.

## Missing from the kit

- **Font files.** The three families named in `KarumFonts` ship with the client under `assets/fonts/` and are declared in the active `fonts:` block of `pubspec.yaml`. The SIL Open Font License files sit beside them, so the families resolve to the bundled files.
- **Lane icons.** The guide's lane glyphs exist only as inline symbols in the guide's own HTML; there are no icon files, so none are checked in. The 24-unit grid rules are recorded in `KarumBrand` for when they land.
- **Maskable PWA icons (192/512).** No such artwork exists, so `manifest.json` declares only what the kit provides.

## Licences

The code is MIT — see [`LICENSE`](LICENSE). The three type families are SIL Open Font License, so adding the font files later is licence-clean. The mark, lockups, and social cards are Karum's own artwork, supplied with the guide for this project.
