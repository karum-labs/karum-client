import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../api/scout_models.dart';
import '../theme/brand_tokens.dart';
import '../util/links.dart';
import 'common.dart';
import 'focus_ring.dart';

/// Opens the evidence drawer for a campaign, optionally scoped to one door.
Future<void> showEvidenceSheet(
  BuildContext context, {
  required Campaign campaign,
  Door? door,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    // The Google map is a DOM element under Flutter's canvas, so wheel and
    // touch events over a dialog reach it and zoom the map. The interceptor
    // fills the screen (the Dialog expands to it) and swallows them.
    builder: (context) => PointerInterceptor(
      child: _EvidenceDialog(campaign: campaign, door: door),
    ),
  );
}

class _EvidenceDialog extends StatelessWidget {
  const _EvidenceDialog({required this.campaign, this.door});

  final Campaign campaign;
  final Door? door;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 720;
    final ids = door?.evidenceIds ?? const <String>[];
    final calls = ids.isEmpty
        ? campaign.evidence
        : campaign.evidence
              .where((call) => ids.contains(call.id))
              .toList(growable: false);
    final shown = calls.isEmpty && ids.isNotEmpty ? campaign.evidence : calls;

    return Dialog(
      insetPadding: EdgeInsets.all(narrow ? KarumSpacing.md : KarumSpacing.xl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: size.height * 0.86,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(
                KarumSpacing.xl,
                KarumSpacing.lg,
                KarumSpacing.md,
                KarumSpacing.md,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How we know',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          door == null
                              ? 'Every recorded call for this campaign.'
                              : 'Evidence behind ${door!.name}.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palette.mute),
                        ),
                      ],
                    ),
                  ),
                  FocusRing(
                    borderRadius: BorderRadius.circular(KarumRadius.control),
                    child: NamedIconButton(
                      key: const Key('evidence-close'),
                      label: 'Close evidence',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icons.close_rounded,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(KarumSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sourceLegend(context),
                    if (door != null) ...[
                      const SizedBox(height: KarumSpacing.xl),
                      const SectionLabel('Door scores'),
                      const SizedBox(height: KarumSpacing.sm),
                      _DoorScoreFacts(door: door!, campaign: campaign),
                      const SizedBox(height: KarumSpacing.xl),
                      const SectionLabel('Affinity inputs'),
                      const SizedBox(height: KarumSpacing.sm),
                      _ExplainabilityFacts(door: door!),
                      const SizedBox(height: KarumSpacing.xl),
                      const SectionLabel('Demographics'),
                      const SizedBox(height: KarumSpacing.sm),
                      _DemographicFacts(door: door!),
                    ],
                    const SizedBox(height: KarumSpacing.xl),
                    Row(
                      children: [
                        const Expanded(child: SectionLabel('Recorded calls')),
                        Text(
                          '${shown.length} shows · append-only',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: palette.mute),
                        ),
                      ],
                    ),
                    const SizedBox(height: KarumSpacing.sm),
                    if (shown.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(KarumSpacing.lg),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            KarumRadius.control,
                          ),
                          border: Border.all(color: palette.line),
                        ),
                        child: Text(
                          'This campaign stored no Qloo calls. That is a '
                          'reported absence, not evidence that none were made.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: palette.mute),
                        ),
                      )
                    else
                      for (final call in shown) ...[
                        _EvidenceCallCard(
                          call: call,
                          highlighted: ids.contains(call.id),
                        ),
                        const SizedBox(height: KarumSpacing.sm),
                      ],
                    if (door?.menu != null) ...[
                      const SizedBox(height: KarumSpacing.xl),
                      const SectionLabel('Menu and shelf citations'),
                      const SizedBox(height: KarumSpacing.sm),
                      _MenuCitations(menu: door!.menu!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceLegend(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KarumSpacing.md),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(KarumRadius.control),
        border: Border.all(color: palette.line),
      ),
      child: Wrap(
        spacing: KarumSpacing.xl,
        runSpacing: KarumSpacing.sm,
        children: const [
          SourceBadge(source: 'qloo_fact'),
          SourceBadge(source: 'model_inference'),
          SourceBadge(source: 'google_fact'),
        ],
      ),
    );
  }
}

class _DoorScoreFacts extends StatelessWidget {
  const _DoorScoreFacts({required this.door, required this.campaign});

  final Door door;
  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final rows = <(String, ScoreTerm?, String)>[
      ('Cultural affinity', door.scores.culturalAffinity, 'A_taste'),
      ('Shelf opportunity', door.scores.shelfOpportunity, 'O_shelf'),
      ('Demographic alignment', door.scores.demographicAlignment, 'D_demo'),
      ('Composite', door.scores.composite, 'S_door'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          campaign.formulaText,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: palette.mute),
        ),
        const SizedBox(height: KarumSpacing.md),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: KarumSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${row.$1}  ·  ${row.$3}',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: palette.ink),
                      ),
                    ),
                    Text(
                      row.$2 == null
                          ? 'Unknown'
                          : row.$2!.partial
                          ? '${row.$2!.displayText} (partial)'
                          : row.$2!.displayText,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: palette.mute),
                    ),
                  ],
                ),
                if (row.$2 != null && row.$2!.inputs.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  for (final input in row.$2!.inputs)
                    Text(
                      '· $input',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.mute),
                    ),
                ],
                const SizedBox(height: 4),
                SourceBadge(source: row.$2?.source ?? 'model_inference'),
              ],
            ),
          ),
      ],
    );
  }
}

/// The per-input contributions behind a door's affinity, as Qloo reported
/// them. An empty list is a reported absence, not a zero contribution.
class _ExplainabilityFacts extends StatelessWidget {
  const _ExplainabilityFacts({required this.door});

  final Door door;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final items = door.explainability;
    if (items.isEmpty) {
      return Text(
        'Qloo reported no per-input contribution for this door. That is a '
        'reported absence, not a zero contribution.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: palette.mute),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Each seed input and the weight Qloo gave it for this door.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: palette.mute),
        ),
        const SizedBox(height: KarumSpacing.sm),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.label.isEmpty ? item.entityId : item.label,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: palette.ink),
                  ),
                ),
                Text(
                  item.score.toStringAsFixed(3),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: palette.mute),
                ),
              ],
            ),
          ),
        const SizedBox(height: KarumSpacing.xs),
        const SourceBadge(source: 'qloo_fact'),
      ],
    );
  }
}

/// The door's demographic profile: the age buckets and the male and female
/// deltas against the population baseline.
class _DemographicFacts extends StatelessWidget {
  const _DemographicFacts({required this.door});

  final Door door;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final demo = door.demographics;
    if (demo == null) {
      return Text(
        'No demographic profile came back for this door, so its demographic '
        'alignment is unknown.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: palette.mute),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (demo.ageBuckets.isEmpty)
          Text(
            'The profile carries no age buckets.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: palette.mute),
          )
        else
          for (final bucket in demo.ageBuckets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      bucket.label,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: palette.ink),
                    ),
                  ),
                  Text(
                    _signed(bucket.delta),
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: palette.mute),
                  ),
                ],
              ),
            ),
        const SizedBox(height: KarumSpacing.xs),
        Text(
          'Male ${_signed(demo.maleDelta)} · female ${_signed(demo.femaleDelta)}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: palette.mute),
        ),
        const SizedBox(height: KarumSpacing.xs),
        const SourceBadge(source: 'qloo_fact'),
      ],
    );
  }

  /// A delta with its sign, so a reader never has to infer one.
  static String _signed(double value) {
    final text = value.toStringAsFixed(2);
    return value > 0 ? '+$text' : text;
  }
}

class _EvidenceCallCard extends StatelessWidget {
  const _EvidenceCallCard({required this.call, required this.highlighted});

  final EvidenceCall call;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KarumSpacing.md),
      decoration: BoxDecoration(
        color: highlighted
            ? palette.brand.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(KarumRadius.control),
        border: Border.all(
          color: highlighted
              ? palette.brand.withValues(alpha: 0.35)
              : palette.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.paper,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: palette.line),
                ),
                child: Text(
                  call.id,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.mute,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: KarumSpacing.sm),
              Expanded(
                child: SelectableText(
                  call.endpoint,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.ink),
                ),
              ),
              Text(
                '${call.resultCount} results',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.mute),
              ),
            ],
          ),
          if (call.parameters.isNotEmpty) ...[
            const SizedBox(height: KarumSpacing.sm),
            Wrap(
              spacing: KarumSpacing.sm,
              runSpacing: KarumSpacing.xs,
              children: [
                for (final parameter in call.parameters)
                  TagPill(label: parameter),
              ],
            ),
          ],
          const SizedBox(height: KarumSpacing.sm),
          SourceBadge(source: call.source),
        ],
      ),
    );
  }
}

class _MenuCitations extends StatelessWidget {
  const _MenuCitations({required this.menu});

  final MenuFinding menu;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (menu.summary.isNotEmpty)
          Text(
            menu.summary,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: palette.ink),
          ),
        if (menu.shelfUnknown)
          Padding(
            padding: const EdgeInsets.only(top: KarumSpacing.sm),
            child: Text(
              'Shelf opportunity is unknown: the audit did not return a '
              'shelf read for this venue.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.investigate),
            ),
          ),
        for (final incumbent in menu.incumbents) ...[
          const SizedBox(height: KarumSpacing.md),
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 16, color: palette.avoid),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  incumbent.name,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: palette.ink),
                ),
              ),
            ],
          ),
          for (final source in incumbent.sources) _Citation(source: source),
        ],
        for (final source in menu.sources) _Citation(source: source),
      ],
    );
  }
}

class _Citation extends StatelessWidget {
  const _Citation({required this.source});

  final SourceLink source;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final label = source.title.isEmpty ? source.url : source.title;
    return InkWell(
      onTap: () async {
        final opened = await openExternal(source.url);
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open that citation.')),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 4, left: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.link_rounded, size: 14, color: palette.brand),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.brand,
                  decoration: TextDecoration.underline,
                  decorationColor: palette.brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
