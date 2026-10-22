import 'package:flutter/material.dart';

import '../theme/brand_tokens.dart';
import 'focus_ring.dart';

/// The Karum glossary.
///
/// Each entry is one brand term and a one-line gloss that explains it
/// without using other brand terms. The three-minute script in
/// `PRODUCT.md` §6.2 keeps the terms it depends on; this glossary meets a
/// first-time visitor where they are (PLAN.md §51).
///
/// The list is the source of truth for both the chrome's glossary sheet
/// (via [showGlossarySheet]) and the inline [GlossTag] used on the screen
/// where each term first appears. Keep entries short enough to read on a
/// 320 px phone without a scroll.
class GlossaryTerm {
  const GlossaryTerm({required this.term, required this.gloss});

  /// The word the visitor sees in the product copy.
  final String term;

  /// A one-line, brand-word-free explanation.
  final String gloss;
}

const List<GlossaryTerm> karumGlossary = <GlossaryTerm>[
  GlossaryTerm(
    term: 'Door',
    gloss:
        'A store or venue the brand could sell at or open at. One door is '
        'one place on the map.',
  ),
  GlossaryTerm(
    term: 'Seed',
    gloss:
        'The brand itself and the taste words that describe it: the kinds of '
        'products, flavours, and audiences the brand already fits.',
  ),
  GlossaryTerm(
    term: 'Door board',
    gloss:
        'The ranked list of doors Karum produced for one search, with the '
        'reason behind each place.',
  ),
  GlossaryTerm(
    term: 'Scout',
    gloss:
        'One search run for a brand in a city. A scout turns a seed and a '
        'city into a door board, a route, and a pitch.',
  ),
  GlossaryTerm(
    term: 'Flagship',
    gloss:
        'The brand\'s own large store, and the stretch of a city where that '
        'kind of store already works.',
  ),
  GlossaryTerm(
    term: 'Collab',
    gloss:
        'A partner brand whose customers overlap with the seed\'s, for a '
        'joint event or a shared pop-up.',
  ),
  GlossaryTerm(
    term: 'Skip list',
    gloss:
        'Places the search looked at and left out, each with a short reason '
        'they were not a fit.',
  ),
  GlossaryTerm(
    term: 'Menu audit',
    gloss:
        'A check of a venue\'s menu against the brand\'s products, so a pitch '
        'can name what already overlaps.',
  ),
  GlossaryTerm(
    term: 'Pitch and battlecard',
    gloss:
        'A short script for approaching a door, with the one-page talking '
        'points behind it.',
  ),
  GlossaryTerm(
    term: 'Baseline',
    gloss:
        'What a generic AI model says about the city without the search, '
        'shown next to Karum\'s result for contrast.',
  ),
];

/// An inline tag that puts a term's gloss next to its first use.
///
/// The visible text stays close to the body copy so a visitor can read
/// linearly; a long-press or focus reveals the full gloss. The gloss is
/// also announced through [Semantics.hint] for screen readers.
class GlossTag extends StatelessWidget {
  const GlossTag({super.key, required this.term});

  final String term;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final match = karumGlossary.firstWhere(
      (entry) => entry.term.toLowerCase() == term.toLowerCase(),
      orElse: () => GlossaryTerm(term: term, gloss: term),
    );
    return Semantics(
      label: match.term,
      hint: match.gloss,
      child: Tooltip(
        message: match.gloss,
        triggerMode: TooltipTriggerMode.tap,
        waitDuration: const Duration(milliseconds: 200),
        showDuration: const Duration(seconds: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KarumSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: palette.brand.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(KarumRadius.pill),
            border: Border.all(
              color: palette.brand.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                match.term,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.help_outline_rounded,
                size: 12,
                color: palette.mute,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A one-line gloss shown directly under a heading on first use. Prefer
/// this over [GlossTag] where the term is in a heading (door board, skip
/// list, collab tab, menu audit): the visitor reads the gloss once at the
/// top of the section rather than being asked to tap a tag.
class GlossNote extends StatelessWidget {
  const GlossNote({super.key, required this.term});

  final String term;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final match = karumGlossary.firstWhere(
      (entry) => entry.term.toLowerCase() == term.toLowerCase(),
      orElse: () => GlossaryTerm(term: term, gloss: term),
    );
    return Semantics(
      container: true,
      label: '${match.term}: ${match.gloss}',
      child: Padding(
        padding: const EdgeInsets.only(top: KarumSpacing.xs),
        child: Text(
          '${match.term} — ${match.gloss}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: palette.mute, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

/// Opens the "What do these words mean?" bottom sheet. The sheet is
/// reachable from the chrome of every screen.
Future<void> showGlossarySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => const _GlossarySheet(),
  );
}

class _GlossarySheet extends StatelessWidget {
  const _GlossarySheet();

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KarumSpacing.lg,
            KarumSpacing.sm,
            KarumSpacing.lg,
            KarumSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'What do these words mean?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: KarumSpacing.xs),
              Text(
                'Karum uses a few terms. Here is what each one means in '
                'plain language.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: palette.mute),
              ),
              const SizedBox(height: KarumSpacing.md),
              Expanded(
                child: ListView.separated(
                  itemCount: karumGlossary.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: palette.line, height: KarumSpacing.lg),
                  itemBuilder: (listContext, index) {
                    final entry = karumGlossary[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.term,
                          style: Theme.of(listContext).textTheme.titleMedium,
                        ),
                        const SizedBox(height: KarumSpacing.xs),
                        Text(
                          entry.gloss,
                          style: Theme.of(listContext).textTheme.bodyMedium
                              ?.copyWith(color: palette.ink, height: 1.45),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: KarumSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: FocusRing(
                  borderRadius: BorderRadius.circular(KarumRadius.control),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
