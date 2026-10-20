import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/gateway_client.dart';
import '../api/scout_models.dart';
import '../app/app_scope.dart';
import '../theme/brand_tokens.dart';
import '../util/file_saver.dart';
import '../util/links.dart';
import '../widgets/async_states.dart';
import '../widgets/common.dart';
import '../widgets/evidence_sheet.dart';
import '../widgets/karum_chrome.dart';

/// The route-addressable pitch surface for one door.
///
/// On a laptop the workspace renders this as the door's full pitch view; the
/// URL is deep-linkable so a judge can restore a single door card.
class DoorPitchScreen extends StatefulWidget {
  const DoorPitchScreen({super.key, required this.jobId, required this.doorId});

  final String jobId;
  final String doorId;

  @override
  State<DoorPitchScreen> createState() => _DoorPitchScreenState();
}

class _DoorPitchScreenState extends State<DoorPitchScreen> {
  late GatewayClient _client;

  Campaign? _campaign;
  bool _loading = true;
  String? _error;
  String? _downloadError;
  bool _downloading = false;
  bool _regenerating = false;

  Door? get _door => _campaign?.doorById(widget.doorId);

  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = AppScope.maybeOf(context)?.client ?? GatewayClient();
    // The client comes from the inherited scope, so the first fetch waits for
    // dependencies instead of running in initState.
    if (!_initialised) {
      _initialised = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final job = await _client.fetchScout(widget.jobId);
      if (!mounted) return;
      setState(() {
        _campaign = job.campaign;
        _loading = false;
        if (job.campaign == null) {
          _error = job.errorMessage.isNotEmpty
              ? job.errorMessage
              : 'The campaign is still running. Open the workspace to watch it '
                    'finish, then return to this door.';
        } else if (job.campaign!.doorById(widget.doorId) == null) {
          _error =
              'That door is not in this campaign. It may have been '
              'regenerated or restored from a different run.';
        }
      });
    } on GatewayException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _copyScript(Pitch pitch) async {
    await Clipboard.setData(ClipboardData(text: pitch.script));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Pitch script copied.')));
  }

  Future<void> _regenerate() async {
    if (_regenerating) return;
    setState(() => _regenerating = true);
    try {
      final campaign = await _client.regenerateDoorPitch(
        widget.jobId,
        widget.doorId,
      );
      if (!mounted) return;
      setState(() {
        _campaign = campaign;
        _regenerating = false;
      });
    } on GatewayException catch (error) {
      if (!mounted) return;
      setState(() => _regenerating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _download() async {
    final campaign = _campaign;
    if (campaign == null || _downloading) return;
    final siteBrief = campaign.mode == ScoutMode.flagship;
    setState(() {
      _downloading = true;
      _downloadError = null;
    });
    try {
      final bytes = await _client.downloadDraft(
        widget.jobId,
        siteBrief: siteBrief,
      );
      await saveBytes(
        bytes,
        filename: siteBrief ? 'site-brief.pdf' : 'run-sheet.pdf',
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(siteBrief ? 'Site brief saved.' : 'Run-sheet saved.'),
        ),
      );
    } on GatewayException catch (error) {
      if (!mounted) return;
      setState(() => _downloadError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _downloadError =
            'The PDF could not be saved: $error. The campaign is unchanged.',
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = _campaign;
    final door = _door;
    return Scaffold(
      body: Column(
        children: [
          KarumHeader(
            showBack: true,
            onNewScout: () => Navigator.of(context).pushNamed('/'),
            onStatus: () => Navigator.of(context).pushNamed('/status'),
            actions: [
              IconButton(
                onPressed: campaign == null || _downloading ? null : _download,
                tooltip: campaign?.mode == ScoutMode.flagship
                    ? 'Download site brief'
                    : 'Download run-sheet',
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 20),
              ),
            ],
          ),
          if (_downloadError != null)
            NoticeBanner(
              title: 'Download failed',
              message: '$_downloadError The campaign is unchanged.',
              tone: NoticeTone.danger,
              icon: Icons.picture_as_pdf_outlined,
            ),
          Expanded(
            child: _loading
                ? const LoadingState(label: 'Opening the door card…')
                : _error != null
                ? ErrorState(
                    title: 'Door unavailable',
                    message: _error!,
                    onRetry: _load,
                  )
                : campaign == null || door == null
                ? const LoadingState(label: 'Opening the door card…')
                : _PitchBody(
                    campaign: campaign,
                    door: door,
                    regenerating: _regenerating,
                    onCopy: () => _copyScript(door.pitch!),
                    onRegenerate: _regenerate,
                    onEvidence: () => showEvidenceSheet(
                      context,
                      campaign: campaign,
                      door: door,
                    ),
                    onBackToBoard: () async {
                      final popped = await Navigator.of(context).maybePop();
                      if (!popped && context.mounted) {
                        Navigator.of(context)
                            .pushNamed('/scout/${campaign.jobId}');
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PitchBody extends StatelessWidget {
  const _PitchBody({
    required this.campaign,
    required this.door,
    required this.regenerating,
    required this.onCopy,
    required this.onRegenerate,
    required this.onEvidence,
    required this.onBackToBoard,
  });

  final Campaign campaign;
  final Door door;
  final bool regenerating;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;
  final VoidCallback onEvidence;
  final VoidCallback onBackToBoard;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final pitch = door.pitch;
    final route = campaign.route;
    final stopIndex = route == null
        ? -1
        : route.stopIds.indexWhere((id) => id == door.id);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 600
                ? KarumSpacing.lg
                : KarumSpacing.xl2,
            vertical: KarumSpacing.xl,
          ),
          children: [
            _PitchHeader(
              campaign: campaign,
              door: door,
              onEvidence: onEvidence,
            ),
            const SizedBox(height: KarumSpacing.xl),
            if (pitch == null || pitch.isEmpty)
              _MissingPitch(
                regenerating: regenerating,
                onRegenerate: onRegenerate,
              )
            else ...[
              _ScriptCard(
                pitch: pitch,
                regenerating: regenerating,
                onCopy: onCopy,
                onRegenerate: onRegenerate,
              ),
              if (pitch.sku != null && pitch.sku!.name.isNotEmpty) ...[
                const SizedBox(height: KarumSpacing.lg),
                _SkuCard(sku: pitch.sku!),
              ],
              if (pitch.battlecard != null) ...[
                const SizedBox(height: KarumSpacing.lg),
                _BattlecardCard(battlecard: pitch.battlecard!),
              ],
              if (pitch.modeParagraph.isNotEmpty) ...[
                const SizedBox(height: KarumSpacing.lg),
                _ModeParagraph(text: pitch.modeParagraph),
              ],
            ],
            const SizedBox(height: KarumSpacing.lg),
            _ScoresCard(door: door),
            const SizedBox(height: KarumSpacing.lg),
            _RouteCard(campaign: campaign, door: door, stopIndex: stopIndex),
            if (door.menu != null) ...[
              const SizedBox(height: KarumSpacing.lg),
              _MenuCard(menu: door.menu!),
            ],
            const SizedBox(height: KarumSpacing.xl),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onBackToBoard,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to the board'),
                ),
                const Spacer(),
                Text(
                  'Door ${door.id}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.mute),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PitchHeader extends StatelessWidget {
  const _PitchHeader({
    required this.campaign,
    required this.door,
    required this.onEvidence,
  });

  final Campaign campaign;
  final Door door;
  final VoidCallback onEvidence;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SectionLabel('Pitch'),
            const SizedBox(width: KarumSpacing.sm),
            ModeChip(mode: campaign.mode),
          ],
        ),
        const SizedBox(height: KarumSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.brand,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${door.rank}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    style: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    door.enrichment?.address.isNotEmpty == true
                        ? door.enrichment!.address
                        : 'Places read unavailable',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: palette.mute),
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
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(fontSize: 40),
                ),
                const SourceBadge(source: 'model_inference'),
              ],
            ),
          ],
        ),
        const SizedBox(height: KarumSpacing.md),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onEvidence,
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Evidence behind this door'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScriptCard extends StatelessWidget {
  const _ScriptCard({
    required this.pitch,
    required this.regenerating,
    required this.onCopy,
    required this.onRegenerate,
  });

  final Pitch pitch;
  final bool regenerating;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.xl2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel('Pitch script')),
                if (pitch.template)
                  const TagPill(label: 'Evidence-only template')
                else
                  const SourceBadge(source: 'model_inference'),
              ],
            ),
            const SizedBox(height: KarumSpacing.md),
            SelectableText(
              pitch.script,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(fontSize: 16, height: 1.6, color: palette.ink),
            ),
            const SizedBox(height: KarumSpacing.lg),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copy script'),
                ),
                const SizedBox(width: KarumSpacing.sm),
                OutlinedButton.icon(
                  onPressed: regenerating ? null : onRegenerate,
                  icon: regenerating
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(regenerating ? 'Regenerating…' : 'Regenerate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkuCard extends StatelessWidget {
  const _SkuCard({required this.sku});

  final Sku sku;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(KarumSpacing.lg),
      decoration: BoxDecoration(
        color: palette.brand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(KarumRadius.card),
        border: Border.all(color: palette.brand.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 18, color: palette.brand),
          const SizedBox(width: KarumSpacing.sm),
          Expanded(
            child: Text(
              'Recommended SKU · ${sku.name}',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _BattlecardCard extends StatelessWidget {
  const _BattlecardCard({required this.battlecard});

  final Battlecard battlecard;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Battlecard'),
            const SizedBox(height: KarumSpacing.md),
            Text(
              battlecard.headline,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: palette.ink),
            ),
            if (battlecard.incumbentName.isNotEmpty) ...[
              const SizedBox(height: KarumSpacing.xs),
              Text(
                'Incumbent · ${battlecard.incumbentName}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.avoid),
              ),
            ],
            if (battlecard.talkingPoints.isNotEmpty) ...[
              const SizedBox(height: KarumSpacing.md),
              for (final point in battlecard.talkingPoints)
                Padding(
                  padding: const EdgeInsets.only(bottom: KarumSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: palette.brand,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: KarumSpacing.sm),
                      Expanded(
                        child: Text(
                          point,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: palette.ink),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeParagraph extends StatelessWidget {
  const _ModeParagraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(KarumSpacing.lg),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(KarumRadius.card),
        border: Border.all(color: palette.line),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: palette.mute),
      ),
    );
  }
}

class _ScoresCard extends StatelessWidget {
  const _ScoresCard({required this.door});

  final Door door;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionLabel('Scores')),
                FormulaBadge(
                  formula: 'S_door = 0.50 · A_taste + 0.30 · O_shelf + 0.20 · D_demo',
                ),
              ],
            ),
            const SizedBox(height: KarumSpacing.lg),
            DoorScores(door: door),
            const SizedBox(height: KarumSpacing.md),
            Wrap(
              spacing: KarumSpacing.md,
              runSpacing: KarumSpacing.xs,
              children: [
                for (final tag in door.sharedTags.take(8))
                  TagPill(label: tag.label),
                if (door.menu != null && door.menu!.shelfUnknown)
                  const TagPill(label: 'Shelf unverified'),
                TagPill(label: door.enrichment?.openLabel ?? 'Places unknown'),
              ],
            ),
            const SizedBox(height: KarumSpacing.md),
            Text(
              'Shelf and demographic terms are labelled unknown when the '
              'upstream did not return a value. The composite still shows its '
              'own source.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.mute),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.campaign,
    required this.door,
    required this.stopIndex,
  });

  final Campaign campaign;
  final Door door;
  final int stopIndex;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final route = campaign.route;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Field route'),
            const SizedBox(height: KarumSpacing.sm),
            if (route == null)
              Text(
                'The gateway stored no route for this campaign. The door order '
                'above is still the recommended visiting order.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: palette.mute),
              )
            else if (route.skipped)
              Text(
                'No route was built${route.skipReason.isEmpty ? '.' : ': '
                          '${route.skipReason.replaceAll('_', ' ')}.'} '
                'Use the server door order as the walk list.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: palette.mute),
              )
            else if (route.failed)
              Text(
                route.error.isEmpty
                    ? 'The route request failed; the door order is unchanged.'
                    : 'The route request failed: ${route.error}',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: palette.avoid),
              )
            else ...[
              Text(
                stopIndex >= 0
                    ? 'Stop ${stopIndex + 1} of ${route.stopIds.length}'
                    : 'Not on the stored route',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: palette.ink),
              ),
              const SizedBox(height: KarumSpacing.sm),
              for (final leg in route.legs.where(
                (leg) => leg.toId == door.id || leg.fromId == door.id,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: KarumSpacing.xs),
                  child: Text(
                    '${leg.fromId == door.id ? 'From' : 'To'} this stop · '
                    '${leg.duration.isEmpty ? 'duration unknown' : leg.duration}'
                    '${leg.distanceMeters > 0 ? ' · ${(leg.distanceMeters / 1000).toStringAsFixed(1)} km' : ''}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: palette.mute),
                  ),
                ),
              if (route.attribution.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: KarumSpacing.sm),
                  child: Text(
                    route.attribution,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: palette.mute),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.menu});

  final MenuFinding menu;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionLabel('Menu grounding')),
                const SourceBadge(source: 'google_fact'),
              ],
            ),
            const SizedBox(height: KarumSpacing.md),
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
                  'Shelf opportunity could not be verified for this venue.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.investigate),
                ),
              ),
            for (final incumbent in menu.incumbents)
              Padding(
                padding: const EdgeInsets.only(top: KarumSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 15,
                      color: palette.avoid,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        incumbent.name,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: palette.ink),
                      ),
                    ),
                  ],
                ),
              ),
            for (final source in menu.sources)
              InkWell(
                onTap: () => openExternal(source.url),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    source.title.isEmpty ? source.url : source.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.brand,
                      decoration: TextDecoration.underline,
                      decorationColor: palette.brand,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MissingPitch extends StatelessWidget {
  const _MissingPitch({required this.regenerating, required this.onRegenerate});

  final bool regenerating;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(KarumSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KarumRadius.card),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No pitch was stored for this door.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: KarumSpacing.xs),
          Text(
            'The gateway can regenerate it on demand. If the AI is unavailable '
            'it returns an evidence-only template and labels it.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: palette.mute),
          ),
          const SizedBox(height: KarumSpacing.lg),
          FilledButton.icon(
            onPressed: regenerating ? null : onRegenerate,
            icon: regenerating
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text(regenerating ? 'Regenerating…' : 'Generate the pitch'),
          ),
        ],
      ),
    );
  }
}
