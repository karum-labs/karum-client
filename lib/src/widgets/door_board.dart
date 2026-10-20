import 'package:flutter/material.dart' hide Baseline;

import '../api/scout_models.dart';
import '../theme/brand_tokens.dart';
import '../util/links.dart';
import 'common.dart';
import 'evidence_sheet.dart';
import 'focus_ring.dart';

/// The door board: recommended doors, the skip list, and the
/// explainability tab.
class DoorBoard extends StatefulWidget {
  const DoorBoard({
    super.key,
    required this.campaign,
    this.onOpenPitch,
    this.onRegenerate,
    this.regeneratingDoorId,
  });

  final Campaign campaign;
  final ValueChanged<Door>? onOpenPitch;
  final ValueChanged<Door>? onRegenerate;
  final String? regeneratingDoorId;

  @override
  State<DoorBoard> createState() => _DoorBoardState();
}

class _DoorBoardState extends State<DoorBoard> {
  bool _showBaseline = false;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final campaign = widget.campaign;
    return _CampaignLookup(
      campaign: campaign,
      child: DefaultTabController(
        length: 3,
        child: Container(
          color: palette.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KarumSpacing.xl,
                  KarumSpacing.xl,
                  KarumSpacing.xl,
                  KarumSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: SectionLabel('Door board')),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              KarumRadius.pill,
                            ),
                            border: Border.all(color: palette.line),
                          ),
                          child: Text(
                            'server order',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: palette.mute),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KarumSpacing.xs),
                    Text(
                      campaign.doors.isEmpty
                          ? 'No doors cleared the floor.'
                          : '${campaign.doors.length} doors · '
                                'tap a card for the pitch and route',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.mute),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KarumSpacing.xl,
                ),
                child: _BaselineToggle(
                  value: _showBaseline,
                  onChanged: (value) => setState(() => _showBaseline = value),
                ),
              ),
              const SizedBox(height: KarumSpacing.xs),
              TabBar(
                labelColor: palette.brand,
                unselectedLabelColor: palette.mute,
                indicatorColor: palette.brand,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                  fontFamily: KarumFonts.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                tabs: [
                  Tab(text: 'Recommended (${campaign.doors.length})'),
                  Tab(text: 'Skip (${campaign.skipList.length})'),
                  const Tab(text: 'How we know'),
                ],
              ),
              Divider(height: 1, color: palette.line),
              Expanded(
                child: TabBarView(
                  children: [
                    _RecommendedTab(
                      campaign: campaign,
                      showBaseline: _showBaseline,
                      onOpenPitch: widget.onOpenPitch,
                      onRegenerate: widget.onRegenerate,
                      regeneratingDoorId: widget.regeneratingDoorId,
                    ),
                    _SkipTab(campaign: campaign),
                    _ExplainTab(campaign: campaign),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaselineToggle extends StatelessWidget {
  const _BaselineToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KarumSpacing.md,
        vertical: KarumSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: value ? palette.avoid.withValues(alpha: 0.08) : palette.paper,
        borderRadius: BorderRadius.circular(KarumRadius.control),
        border: Border.all(
          color: value ? palette.avoid.withValues(alpha: 0.35) : palette.line,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_alt_outlined, size: 16, color: palette.mute),
          const SizedBox(width: KarumSpacing.sm),
          Expanded(
            child: Text(
              'Compare with the generic LLM baseline',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.ink),
            ),
          ),
          // The switch is its own control, so it needs its own name. The
          // label beside it is a different node; without this the switch is
          // announced as an unlabelled toggle.
          Semantics(
            label: 'Compare with the generic LLM baseline',
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _RecommendedTab extends StatelessWidget {
  const _RecommendedTab({
    required this.campaign,
    required this.showBaseline,
    required this.onOpenPitch,
    required this.onRegenerate,
    required this.regeneratingDoorId,
  });

  final Campaign campaign;
  final bool showBaseline;
  final ValueChanged<Door>? onOpenPitch;
  final ValueChanged<Door>? onRegenerate;
  final String? regeneratingDoorId;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return ListView(
      padding: const EdgeInsets.all(KarumSpacing.lg),
      children: [
        if (showBaseline) ...[
          _BaselineCard(baseline: campaign.baseline),
          const SizedBox(height: KarumSpacing.lg),
        ],
        if (campaign.doors.isEmpty)
          _NoDoors(campaign: campaign)
        else
          for (var i = 0; i < campaign.doors.length; i++) ...[
            if (i > 0) const SizedBox(height: KarumSpacing.md),
            _DoorCard(
              door: campaign.doors[i],
              firstStop: i == 0,
              onOpenPitch: onOpenPitch,
              onRegenerate: onRegenerate,
              regenerating: regeneratingDoorId == campaign.doors[i].id,
            ),
          ],
        if (campaign.warnings.isNotEmpty) ...[
          const SizedBox(height: KarumSpacing.lg),
          for (final warning in campaign.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: KarumSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: palette.investigate,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.mute),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _DoorCard extends StatelessWidget {
  const _DoorCard({
    required this.door,
    required this.firstStop,
    required this.onOpenPitch,
    required this.onRegenerate,
    required this.regenerating,
  });

  final Door door;
  final bool firstStop;
  final ValueChanged<Door>? onOpenPitch;
  final ValueChanged<Door>? onRegenerate;
  final bool regenerating;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final pitch = door.pitch;
    final menu = door.menu;
    final enrichment = door.enrichment;
    final place = door.place;
    final enrichmentAddress = enrichment?.address.isNotEmpty == true
        ? enrichment!.address
        : '';
    final address = enrichmentAddress.isNotEmpty
        ? enrichmentAddress
        : (place?.address.isNotEmpty == true ? place!.address : '');
    final addressFromQloo = enrichmentAddress.isEmpty && address.isNotEmpty;
    final enrichmentWebsite = enrichment?.website.isNotEmpty == true
        ? enrichment!.website
        : '';
    final website = enrichmentWebsite.isNotEmpty
        ? enrichmentWebsite
        : (place?.website ?? '');
    final websiteFromQloo = enrichmentWebsite.isEmpty && website.isNotEmpty;
    final enrichmentHours = enrichment?.hours.isNotEmpty == true
        ? enrichment!.hours
        : '';
    final hours = enrichmentHours.isNotEmpty
        ? enrichmentHours
        : (place?.hours ?? '');
    final hoursFromQloo = enrichmentHours.isEmpty && hours.isNotEmpty;
    final phone = place?.phone ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (firstStop) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KarumRadius.pill),
                ),
                child: Text(
                  'FIRST STOP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.brand,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: KarumSpacing.sm),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.brand,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${door.rank}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: palette.onBrand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: KarumSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        door.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: palette.ink),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            address.isNotEmpty
                                ? address
                                : 'Places read unavailable',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palette.mute),
                          ),
                          if (addressFromQloo)
                            const SourceBadge(source: 'qloo_fact'),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      door.compositePercent == null
                          ? '—'
                          : '${door.compositePercent!.round()}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: palette.ink, fontSize: 30),
                    ),
                    const SourceBadge(source: 'model_inference'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: KarumSpacing.lg),
            DoorScores(door: door),
            const SizedBox(height: KarumSpacing.lg),
            Wrap(
              spacing: KarumSpacing.sm,
              runSpacing: KarumSpacing.xs,
              children: [
                for (final tag in door.sharedTags.take(6))
                  TagPill(label: tag.label),
                if (enrichment != null)
                  TagPill(
                    label: enrichment.openLabel,
                    selected: enrichment.openStatus == 'operational',
                  ),
                if (place?.isClosed == true)
                  const TagPill(label: 'Closed per Qloo'),
                if (menu != null && menu.shelfUnknown)
                  TagPill(label: 'Shelf unverified', selected: false),
              ],
            ),
            if (website.isNotEmpty || hours.isNotEmpty || phone.isNotEmpty) ...[
              const SizedBox(height: KarumSpacing.md),
              if (website.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: FactRow(
                        icon: Icons.language_rounded,
                        text: _host(website),
                        onTap: () => openExternal(website),
                      ),
                    ),
                    if (websiteFromQloo) const SourceBadge(source: 'qloo_fact'),
                  ],
                ),
              if (hours.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: FactRow(
                          icon: Icons.schedule_rounded,
                          text: hours,
                        ),
                      ),
                      if (hoursFromQloo) const SourceBadge(source: 'qloo_fact'),
                    ],
                  ),
                ),
              if (phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: FactRow(icon: Icons.phone_rounded, text: phone),
                      ),
                      const SourceBadge(source: 'qloo_fact'),
                    ],
                  ),
                ),
            ],
            if (menu != null) ...[
              const SizedBox(height: KarumSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(KarumSpacing.md),
                decoration: BoxDecoration(
                  color: palette.paper,
                  borderRadius: BorderRadius.circular(KarumRadius.control),
                  border: Border.all(color: palette.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Menu audit',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: palette.ink),
                          ),
                        ),
                        const SourceBadge(source: 'google_fact'),
                      ],
                    ),
                    if (menu.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        menu.summary,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.mute),
                      ),
                    ],
                    if (menu.competitorCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${menu.competitorCount} incumbents on the shelf',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.mute),
                      ),
                    ],
                    for (final incumbent in menu.incumbents.take(3))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 14,
                              color: palette.avoid,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                incumbent.name,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: palette.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_citations(menu).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      for (final source in _citations(menu))
                        InkWell(
                          onTap: () => openExternal(source.url),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: 13,
                                  color: palette.brand,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    source.title.isEmpty
                                        ? source.url
                                        : source.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: palette.brand,
                                          decoration: TextDecoration.underline,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
            if (door.compare?.available == true) ...[
              const SizedBox(height: KarumSpacing.md),
              Text(
                door.compare!.tags.isEmpty
                    ? 'Audience overlap available'
                    : 'Audience overlap: ${door.compare!.tags.map((tag) => tag.label).join(', ')}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.brand),
              ),
            ],
            if (pitch != null) ...[
              const SizedBox(height: KarumSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(KarumSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KarumRadius.control),
                  border: Border.all(color: palette.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pitch',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: palette.ink),
                          ),
                        ),
                        if (pitch.template)
                          TagPill(label: 'Template draft', selected: false),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pitch.script,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.mute),
                    ),
                    if (pitch.sku != null && pitch.sku!.name.isNotEmpty) ...[
                      const SizedBox(height: KarumSpacing.sm),
                      TagPill(
                        label: 'SKU · ${pitch.sku!.name}',
                        selected: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: KarumSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: KarumSpacing.sm,
                    runSpacing: KarumSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (onOpenPitch != null)
                        FocusRing(
                          borderRadius: BorderRadius.circular(
                            KarumRadius.control,
                          ),
                          child: FilledButton.icon(
                            key: const Key('door-pitch'),
                            onPressed: () => onOpenPitch!(door),
                            icon: const Icon(Icons.campaign_outlined, size: 18),
                            label: const Text('Pitch & route'),
                          ),
                        ),
                      FocusRing(
                        borderRadius: BorderRadius.circular(
                          KarumRadius.control,
                        ),
                        child: OutlinedButton.icon(
                          onPressed: () => showEvidenceSheet(
                            context,
                            campaign: _CampaignLookup.of(context),
                            door: door,
                          ),
                          icon: const Icon(Icons.fact_check_outlined, size: 18),
                          label: const Text('Evidence'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRegenerate != null)
                  FocusRing(
                    borderRadius: BorderRadius.circular(KarumRadius.control),
                    child: NamedIconButton(
                      label: 'Regenerate this pitch',
                      onPressed: regenerating
                          ? null
                          : () => onRegenerate!(door),
                      icon: Icons.refresh_rounded,
                      iconSize: 20,
                      busy: regenerating,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _host(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.host;
  }

  /// Deduped clickable grounding links for the menu read: incumbent sources
  /// first, then the audit's own citations.
  List<SourceLink> _citations(MenuFinding menu) {
    final seen = <String>{};
    return [
      for (final source in [
        for (final incumbent in menu.incumbents) ...incumbent.sources,
        ...menu.sources,
      ])
        if (source.url.isNotEmpty && seen.add(source.url)) source,
    ];
  }
}

/// A board-local lookup so the evidence button can pass the campaign without
/// drilling it through every card constructor.
class _CampaignLookup extends InheritedWidget {
  const _CampaignLookup({required this.campaign, required super.child});

  final Campaign campaign;

  static Campaign of(BuildContext context) {
    final lookup = context
        .dependOnInheritedWidgetOfExactType<_CampaignLookup>();
    assert(lookup != null, 'No campaign above this door card.');
    return lookup!.campaign;
  }

  @override
  bool updateShouldNotify(_CampaignLookup oldWidget) =>
      campaign != oldWidget.campaign;
}

class _NoDoors extends StatelessWidget {
  const _NoDoors({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final skipped = campaign.skipList.length;
    return Container(
      padding: const EdgeInsets.all(KarumSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KarumRadius.card),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.door_front_door_outlined, size: 28, color: palette.mute),
          const SizedBox(height: KarumSpacing.md),
          Text(
            'No doors cleared this floor.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: KarumSpacing.xs),
          Text(
            skipped == 0
                ? 'The gateway returned an empty board without a skip list. '
                      'Widen the radius or change the seed and run it again.'
                : '$skipped candidates were checked and placed on the skip '
                      'list with a reason. Adjust the seed or radius and run '
                      'it again.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: palette.mute),
          ),
          const SizedBox(height: KarumSpacing.lg),
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Adjust the seed'),
          ),
        ],
      ),
    );
  }
}

class _SkipTab extends StatelessWidget {
  const _SkipTab({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    if (campaign.skipList.isEmpty) {
      return PanePlaceholder(
        icon: Icons.checklist_rounded,
        title: 'Nothing was skipped',
        message: campaign.doors.isEmpty
            ? 'The gateway returned no candidates and no skip reasons.'
            : 'Every candidate that passed the resolver cleared the floor. '
                  'The board is the whole returned shortlist.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(KarumSpacing.lg),
      itemCount: campaign.skipList.length,
      separatorBuilder: (_, _) => const SizedBox(height: KarumSpacing.sm),
      itemBuilder: (context, index) {
        final skip = campaign.skipList[index];
        return Container(
          padding: const EdgeInsets.all(KarumSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KarumRadius.control),
            border: Border.all(color: palette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.do_not_disturb_on_outlined,
                    size: 18,
                    color: palette.avoid,
                  ),
                  const SizedBox(width: KarumSpacing.sm),
                  Expanded(
                    child: Text(
                      skip.name,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: palette.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KarumSpacing.xs),
              Text(
                skip.reasonLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.avoid,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: KarumSpacing.sm),
              Wrap(
                spacing: KarumSpacing.lg,
                runSpacing: KarumSpacing.xs,
                children: [
                  if (skip.rawAffinity > 0)
                    Text(
                      'raw affinity ${skip.rawAffinity.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.mute),
                    ),
                  if (skip.floor > 0)
                    Text(
                      'floor ${skip.floor.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.mute),
                    ),
                  if (skip.competitorCount > 0)
                    Text(
                      '${skip.competitorCount} incumbents',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.mute),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExplainTab extends StatelessWidget {
  const _ExplainTab({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return ListView(
      padding: const EdgeInsets.all(KarumSpacing.lg),
      children: [
        Text(
          'Three scores, one formula.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: KarumSpacing.xs),
        Text(
          campaign.formulaText,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: palette.mute),
        ),
        const SizedBox(height: KarumSpacing.lg),
        const SectionLabel('Sources'),
        const SizedBox(height: KarumSpacing.sm),
        const Wrap(
          spacing: KarumSpacing.lg,
          runSpacing: KarumSpacing.sm,
          children: [
            SourceBadge(source: 'qloo_fact'),
            SourceBadge(source: 'model_inference'),
            SourceBadge(source: 'google_fact'),
          ],
        ),
        const SizedBox(height: KarumSpacing.lg),
        Text(
          'Qloo facts are the association and demographic inputs. Model '
          'inference is the gateway\'s assembly step; it never overrides a '
          'returned fact. Google facts are the Places read and the grounded '
          'menu citations. When a term is missing, the card says unknown.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: palette.mute),
        ),
        const SizedBox(height: KarumSpacing.xl),
        const SectionLabel('Evidence'),
        const SizedBox(height: KarumSpacing.sm),
        Text(
          '${campaign.evidence.length} recorded Qloo calls for this campaign. '
          'The drawer lists the endpoint, parameters, result count, and source '
          'for each one.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: palette.mute),
        ),
        const SizedBox(height: KarumSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => showEvidenceSheet(context, campaign: campaign),
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('Open evidence drawer'),
          ),
        ),
        if (campaign.baseline.hasText ||
            campaign.baseline.errorCode.isNotEmpty) ...[
          const SizedBox(height: KarumSpacing.xl),
          _BaselineCard(baseline: campaign.baseline),
        ],
      ],
    );
  }
}

class _BaselineCard extends StatelessWidget {
  const _BaselineCard({required this.baseline});

  final Baseline baseline;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KarumSpacing.lg),
      decoration: BoxDecoration(
        color: palette.avoid.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(KarumRadius.card),
        border: Border.all(color: palette.avoid.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_alt_outlined,
                size: 18,
                color: palette.avoid,
              ),
              const SizedBox(width: KarumSpacing.sm),
              Expanded(
                child: Text(
                  'Generic LLM baseline',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: palette.ink),
                ),
              ),
              if (baseline.ungrounded)
                const SourceBadge(source: 'llm_ungrounded'),
            ],
          ),
          const SizedBox(height: KarumSpacing.sm),
          if (baseline.hasText)
            SelectableText(
              baseline.text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.ink),
            )
          else
            Text(
              baseline.errorCode.isEmpty
                  ? 'The baseline was not stored for this run.'
                  : 'Baseline unavailable (${baseline.errorCode}). The Qloo '
                        'board above is unaffected.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.mute),
            ),
          const SizedBox(height: KarumSpacing.sm),
          Text(
            'This answer used no Qloo facts, no Places read, and no menu '
            'grounding. It is shown for contrast, never as a recommendation.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: palette.mute),
          ),
          if (baseline.venueNames.isNotEmpty) ...[
            const SizedBox(height: KarumSpacing.md),
            Wrap(
              spacing: KarumSpacing.sm,
              runSpacing: KarumSpacing.xs,
              children: [
                for (final name in baseline.venueNames) TagPill(label: name),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
