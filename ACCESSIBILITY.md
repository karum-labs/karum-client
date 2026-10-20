# Accessibility pass

The recorded audit for the client, and the reason it exists.

`PLAN.md` §30 asked for "focus order, labels, and contrast set for a short audit". This
is that audit: what was checked, how, what was found, and what now holds it in place.
Every claim here is backed by a test in `test/accessibility_test.dart` — the numbers
in this document are the ones the test computes, not the ones the brand guide
publishes.

**Date of the pass:** 20 Oct 2026
**Scope:** the judge path — the seed builder, the workspace, the door board, the door
card, the evidence sheet, and the pitch. Both themes. 1440×900 and 420×900.

## Method

| Check | How | Held by |
| --- | --- | --- |
| Contrast of every painted pair | WCAG 2.1 relative luminance, computed in the test | `contrast every text pair the app paints clears WCAG AA` |
| Contrast of the theme slots the guide never named | the same, over `ColorScheme` | `contrast the theme slots the guide does not name still clear AA` |
| Accessible names | the semantics tree, not the tooltip | `labels every icon button on the landing carries a label`, `labels every icon button on the board carries a label` |
| Every tappable control is named | Flutter's `labeledTapTargetGuideline` | the three `tap targets` tests |
| The focus ring | the ring's own state | `focus the ring follows the keyboard onto the primary action` |
| The keyboard reaches the pitch | Tab, then Enter | `focus tabbing reaches the pitch and Enter opens it` |
| The map is not a keyboard surface | the tab walk | `focus the map pins are not tab stops` |

Run them with:

```
flutter test test/accessibility_test.dart
```

## Contrast

Text pairs must clear 4.5:1 (WCAG AA). Marks — the coloured dots and lane accents —
must clear 3:1. The hairline is exempt, and the exemption is asserted, so it cannot
become a silent way to hide meaning.

| Pair | Colours | Ratio | Kind |
| --- | --- | --- | --- |
| ink on paper | `16211F` on `F4F5F1` | 15.08:1 | text |
| ink on surface | `16211F` on `FFFFFF` | 16.52:1 | text |
| mute on paper | `56605D` on `F4F5F1` | 5.94:1 | text |
| mute on surface | `56605D` on `FFFFFF` | 6.51:1 | text |
| brand on paper | `0F4C4A` on `F4F5F1` | 8.91:1 | text |
| brand on surface | `0F4C4A` on `FFFFFF` | 9.75:1 | text |
| on brand | `F4F5F1` on `0F4C4A` | 8.91:1 | text |
| approach on paper | `1B6B45` on `F4F5F1` | 5.93:1 | mark |
| approach on surface | `1B6B45` on `FFFFFF` | 6.49:1 | mark |
| investigate on paper | `8A5300` on `F4F5F1` | 5.78:1 | mark |
| investigate on surface | `8A5300` on `FFFFFF` | 6.33:1 | mark |
| avoid on paper | `9E2B2B` on `F4F5F1` | 6.77:1 | mark |
| avoid on surface | `9E2B2B` on `FFFFFF` | 7.41:1 | mark |
| ink on paper (dark) | `E9ECE6` on `0D1514` | 15.52:1 | text |
| ink on surface (dark) | `E9ECE6` on `141E1C` | 14.29:1 | text |
| mute on paper (dark) | `9AA5A1` on `0D1514` | 7.29:1 | text |
| mute on surface (dark) | `9AA5A1` on `141E1C` | 6.71:1 | text |
| brand on paper (dark) | `6FC4BA` on `0D1514` | 9.06:1 | text |
| brand on surface (dark) | `6FC4BA` on `141E1C` | 8.34:1 | text |
| on brand (dark) | `0D1514` on `6FC4BA` | 9.06:1 | text |
| line on paper | `D8DCD5` on `F4F5F1` | 1.27:1 | hairline, exempt |

The lowest text pair is `mute` on paper at 5.94:1, and the lowest mark is `investigate`
on paper at 5.78:1. Both clear AA with room to spare.

Two more pairs are checked because the app paints them rather than the guide naming
them: the selected tag paints `brand` on a 12% `brand` wash over the page, and
Material derives the chip and button slots from the seed colour. Both clear 4.5:1.

## The focus ring

The guide publishes the focus treatment as official: **3 px of brand colour, offset
2 px from the control**. It is now implemented rather than described.

- `KarumBrand.focusRingWidth` (3) and `KarumBrand.focusRingOffset` (2) are the tokens.
- `lib/src/widgets/focus_ring.dart` paints the ring with a `CustomPainter` outside
  the control's bounds, so the ring costs no space and moving focus never reflows the
  page. Flutter has no `outline-offset`, so the offset is the gap between the
  control's edge and the ring's inner edge.
- The offset is what makes the ring work on a filled brand button: a brand ring drawn
  on the button's own edge would be brand on brand and would not read at all.

The ring is on the judge path: the mode pills, the category chips, the free-entry
call to action, the hero sample, the preset buttons, the header's back, home, new
scout and status, the board's **Pitch & route**, Evidence and regenerate, the pitch
screen's download, evidence, copy and regenerate, and the evidence sheet's close.

Text fields already showed a 3 px brand border on focus and keep it.

## Focus order

The order is the widget order — there is no custom traversal layer, and there is
nothing to keep in sync. The keyboard walks:

**The landing** — the brand field, the vibe field, the SKU field, their suffix
buttons, the mode pills, the category chips, the preset buttons, then the free-entry
call to action. The Austin preset is the fifth stop.

**The workspace** — the header's back, home, new scout and status, the download
button, the trace panel, the map's list toggle, the board's tabs, the door card's
**Pitch & route**, Evidence and regenerate. The pitch button is the thirteenth stop.

**The door card** — **Pitch & route**, Evidence, regenerate. Tab to **Pitch & route**
and press Enter: the door card opens.

The map is deliberately not in that order. It draws its own focus scope, and a focus
that lands inside it is trapped: Tab walks the map and never reaches the board. The
map is excluded from the keyboard for that reason, and the map's own toggle — Map or
List — sits outside the scope and stays reachable. The map carries a list of the same
doors in the same order, and that list is what the keyboard uses.

## Labels

Every control on the judge path carries an accessible name.

| Control | Name | Where it comes from |
| --- | --- | --- |
| Back | Back | the button's text |
| Karum home | Karum home | `Semantics` on the logo |
| New scout, Status | New scout, Status | the button's text |
| Download run-sheet / site brief | Download run-sheet / Download site brief | the icon's semantic label |
| Search for the typed brand | Search for the typed brand | the icon's semantic label |
| Add this vibe, Add this SKU | Add this vibe, Add this SKU | the icon's semantic label |
| Close evidence | Close evidence | the icon's semantic label |
| Close door preview | Close door preview | the icon's semantic label |
| Regenerate this pitch | Regenerate this pitch | the icon's semantic label |
| Compare with the generic LLM baseline | Compare with the generic LLM baseline | `Semantics` on the switch |
| Recommended door 1: Whisler's | Recommended door 1: Whisler's | `Semantics` on the pin |
| Pitch & route, Evidence | Pitch & route, Evidence | the button's text |
| Board tabs | Recommended (1), Tab 1 of 3 | the tab's text and position |
| Score bars | Cultural affinity 72, from Qloo | `Semantics` on each bar |

## What the pass found

Five things were broken. All five are fixed, and each has a test.

**1. The primary button had no visible focus indicator.** The theme gave text fields a
focused border and left buttons to Material's default, which is a 12% overlay of the
primary colour — brand on brand on a filled brand button. The brand tokens already
recorded the intended treatment and said it landed with this audit. Fixed by
`FocusRing`.

**2. A covered route kept the keyboard.** Running a scout pushes the workspace over
the landing. The landing kept the focus it had — on the control the judge pressed —
and Flutter then deactivated that route, so the keyboard was walking a route that was
no longer on screen and could not reach the board at all. The workspace now claims
the focus for its own scope when it opens, which is also what a single-page app
should do when the view changes.

**3. The map trapped the keyboard.** See "Focus order" above. Fixed by taking the map
out of the tab order.

**4. Icon buttons had no accessible name.** Flutter's `IconButton` puts its tooltip
in the *tooltip* field of the semantics node, not in the label, and a tooltip only
reaches the semantics tree while it is on screen. Every icon button in the app was
announced as an unlabelled button. `NamedIconButton` puts the name on the icon,
which is what the semantics tree reads.

**5. The baseline switch had no accessible name.** The text beside it is a different
node; the switch itself was an unlabelled toggle. Fixed with `Semantics`.

One more thing surfaced on the way, which is a bug rather than an accessibility
finding: opening the door card with the keyboard crashed the layout. `SectionLabel`
put an `Expanded` in a `Row`, which needs a bounded width, and the door card's
header is laid out in a context that does not always bound it. `SectionLabel` now
falls back to the label's own width where the width is not bounded.

## Known gaps

- Only the judge path carries the focus ring. The other controls keep Material's own
  focus styling, which is a 12% overlay — visible on an outlined button, invisible on
  a filled one. The path is the one a judge walks; the rest is still open.
- The map's pins keep their semantics — a screen reader reaches them and can select a
  door — but they are not tab stops, so a keyboard user reads the list instead.
- The board's door cards are a single semantics node with the card's text merged into
  it. A screen reader reads the card as one block, then reaches the buttons.
- Nothing here was checked with a screen reader. The names are in the semantics tree
  and the tap targets are checked by Flutter's own guideline, but a screen-reader
  pass is still owed.
- The contrast table covers the pairs the app paints. A pair added later is not
  covered until the test's table is extended.
