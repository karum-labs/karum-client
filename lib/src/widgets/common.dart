import 'package:flutter/material.dart';

import '../api/scout_models.dart';
import '../theme/brand_tokens.dart';

/// A small uppercase section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.mute,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A provenance badge. The guide's source dot marks the source of a number;
/// the label makes the same distinction explicit for screen readers.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final normalized = source.toLowerCase();
    final (label, color) = switch (normalized) {
      'qloo_fact' => ('Qloo fact', palette.brand),
      'google_fact' => ('Google fact', palette.investigate),
      'model_inference' => ('Model inference', palette.mute),
      'llm_ungrounded' => ('Ungrounded LLM', palette.avoid),
      'fixture' => ('Fixture', palette.investigate),
      _ => (source.isEmpty ? 'Source unknown' : source, palette.mute),
    };
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: KarumBrand.sourceDotRadius * 2,
            height: KarumBrand.sourceDotRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: normalized == 'model_inference' ? Colors.transparent : color,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.mute,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A bordered tag pill used for Qloo tags.
class TagPill extends StatelessWidget {
  const TagPill({super.key, required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: selected
            ? palette.brand.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(KarumRadius.pill),
        border: Border.all(
          color: selected ? palette.brand.withValues(alpha: 0.4) : palette.line,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: selected ? palette.brand : palette.mute,
        ),
      ),
    );
  }
}

/// A score bar that distinguishes a returned value from an explicitly unknown
/// one. Values are 0–100, matching the gateway's display number.
class ScoreBar extends StatelessWidget {
  const ScoreBar({
    super.key,
    required this.label,
    required this.score,
    required this.color,
    this.compact = false,
  });

  final String label;
  final ScoreTerm? score;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final value = score?.percent;
    final known = value != null;
    return Semantics(
      label: known
          ? '$label ${value.round()} out of 100'
          : '$label unknown',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: (compact
                          ? Theme.of(context).textTheme.labelSmall
                          : Theme.of(context).textTheme.bodySmall)
                      ?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: KarumSpacing.sm),
              Text(
                known ? '${value.round()}' : 'Unknown',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: known ? palette.ink : palette.mute,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (known)
            ClipRRect(
              borderRadius: BorderRadius.circular(KarumRadius.pill),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: compact ? 4 : 6,
                backgroundColor: palette.line,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Container(
              height: compact ? 4 : 6,
              decoration: BoxDecoration(
                color: palette.line,
                borderRadius: BorderRadius.circular(KarumRadius.pill),
              ),
            ),
        ],
      ),
    );
  }
}

/// The three interpretable score terms for a door.
class DoorScores extends StatelessWidget {
  const DoorScores({super.key, required this.door, this.compact = false});

  final Door door;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Column(
      children: [
        ScoreBar(
          label: 'Cultural affinity',
          score: door.scores.culturalAffinity,
          color: palette.brand,
          compact: compact,
        ),
        const SizedBox(height: 8),
        ScoreBar(
          label: 'Shelf opportunity',
          score: door.scores.shelfOpportunity,
          color: palette.approach,
          compact: compact,
        ),
        const SizedBox(height: 8),
        ScoreBar(
          label: 'Demographic alignment',
          score: door.scores.demographicAlignment,
          color: palette.investigate,
          compact: compact,
        ),
      ],
    );
  }
}

/// A compact icon-and-label fact.
class FactRow extends StatelessWidget {
  const FactRow({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final tint = color ?? palette.mute;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: tint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: onTap == null ? palette.mute : palette.brand,
              decoration: onTap == null ? null : TextDecoration.underline,
              decorationColor: palette.brand,
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: row),
    );
  }
}

/// The score formula, with an accessible tooltip.
class FormulaBadge extends StatelessWidget {
  const FormulaBadge({super.key, required this.formula});

  final String formula;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Tooltip(
      message: formula,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: 'Score formula: $formula',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KarumRadius.pill),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: 13, color: palette.mute),
              const SizedBox(width: 4),
              Text(
                'Formula',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.mute,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet empty panel used inside a pane before a campaign exists.
class PanePlaceholder extends StatelessWidget {
  const PanePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: palette.mute),
            const SizedBox(height: KarumSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.ink,
              ),
            ),
            const SizedBox(height: KarumSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.mute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
