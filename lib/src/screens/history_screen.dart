import 'package:flutter/material.dart';

import '../api/gateway_client.dart';
import '../api/scout_models.dart';
import '../api/scout_request.dart';
import '../app/app_scope.dart';
import '../theme/brand_tokens.dart';
import '../widgets/async_states.dart';
import '../widgets/common.dart';
import '../widgets/focus_ring.dart';
import '../widgets/karum_chrome.dart';

/// The signed-in account's run history: campaigns started while signed in,
/// newest first. Each row restores its stored run or re-runs a preset.
///
/// Anonymous visitors never reach this route: `GET /api/v1/account/campaigns`
/// requires a session and is owner-scoped (PLAN.md §49).
class CampaignHistoryScreen extends StatefulWidget {
  const CampaignHistoryScreen({super.key});

  @override
  State<CampaignHistoryScreen> createState() => _CampaignHistoryScreenState();
}

String _createdLabel(AccountCampaign campaign) {
  final diff = DateTime.now().difference(campaign.createdAt);
  if (diff.inDays > 0) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'just now';
}

class _CampaignHistoryScreenState extends State<CampaignHistoryScreen> {
  late GatewayClient _client;
  List<AccountCampaign> _campaigns = const [];
  bool _loading = true;
  Object? _error;
  bool _running = false;

  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = AppScope.maybeOf(context)?.client ?? GatewayClient();
    if (!_initialised) {
      _initialised = true;
      _load();
    }
  }

  Future<void> _load() async {
    if (AppScope.maybeOf(context)?.session == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Sign in to see your run history.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final campaigns = await _client.fetchAccountCampaigns();
      if (!mounted) return;
      setState(() {
        _campaigns = campaigns;
        _loading = false;
      });
    } on GatewayException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The run history could not be loaded: $error';
      });
    }
  }

  Future<void> _open(String campaignId) async {
    if (_running) return;
    setState(() => _running = true);
    try {
      // Restoring a stored run never starts a paid scout.
      if (!mounted) return;
      Navigator.of(context).pushNamed('/campaigns/$campaignId');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _runAgain(AccountCampaign campaign) async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final job = await _client.createScout(
        ScoutRequest.preset(campaign.presetId),
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed('/scout/${job.jobId}');
    } on GatewayException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not re-run the campaign: $error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Scaffold(
      body: Column(
        children: [
          KarumHeader(
            onNewScout: () =>
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false),
            onStatus: () => Navigator.of(context).pushNamed('/status'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 600
                    ? KarumSpacing.lg
                    : KarumSpacing.page,
                vertical: KarumSpacing.xl2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: KarumLayout.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your run history',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: KarumSpacing.sm),
                      Text(
                        'Campaigns started while signed in, newest first. '
                        'Open a run to restore it, or run a preset again.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: palette.mute),
                      ),
                      const SizedBox(height: KarumSpacing.xl),
                      if (_loading && _campaigns.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: KarumSpacing.xl,
                          ),
                          child: LoadingState(label: 'Loading your runs…'),
                        )
                      else if (_error != null && _campaigns.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: KarumSpacing.xl,
                          ),
                          child: ErrorState(
                            title: 'Run history unavailable',
                            message: '$_error',
                            onRetry: _load,
                          ),
                        )
                      else if (_campaigns.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: KarumSpacing.xl,
                          ),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(KarumSpacing.xl),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 30,
                                    color: palette.mute,
                                  ),
                                  const SizedBox(height: KarumSpacing.md),
                                  Text(
                                    'No runs yet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: KarumSpacing.xs),
                                  Text(
                                    'Start a search from the landing page '
                                    'while signed in. Each run lands here.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: palette.mute),
                                  ),
                                  const SizedBox(height: KarumSpacing.lg),
                                  FocusRing(
                                    borderRadius: BorderRadius.circular(
                                      KarumRadius.control,
                                    ),
                                    child: FilledButton(
                                      onPressed: () => Navigator.of(context)
                                          .pushNamedAndRemoveUntil(
                                            '/',
                                            (route) => false,
                                          ),
                                      child: const Text('Start a scout'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ..._campaigns.map(
                          (campaign) => _CampaignRow(
                            campaign: campaign,
                            onOpen: () => _open(campaign.id),
                            onRunAgain: campaign.presetId.isNotEmpty
                                ? () => _runAgain(campaign)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignRow extends StatelessWidget {
  const _CampaignRow({
    required this.campaign,
    required this.onOpen,
    this.onRunAgain,
  });

  final AccountCampaign campaign;
  final VoidCallback onOpen;
  final VoidCallback? onRunAgain;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ModeChip(mode: campaign.mode),
                const Spacer(),
                Text(
                  _createdLabel(campaign),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.mute),
                ),
                if (campaign.hasRun) ...[
                  const SizedBox(width: KarumSpacing.sm),
                  const TagPill(label: 'Stored run', selected: true),
                ],
              ],
            ),
            const SizedBox(height: KarumSpacing.md),
            Text(
              campaign.label,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: palette.ink),
            ),
            const SizedBox(height: KarumSpacing.xs),
            Text(
              '${campaign.brandName} · ${campaign.city}',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.mute),
            ),
            const SizedBox(height: KarumSpacing.lg),
            Wrap(
              spacing: KarumSpacing.sm,
              runSpacing: KarumSpacing.sm,
              children: [
                FocusRing(
                  borderRadius: BorderRadius.circular(KarumRadius.control),
                  child: OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open'),
                  ),
                ),
                if (onRunAgain != null)
                  FocusRing(
                    borderRadius: BorderRadius.circular(KarumRadius.control),
                    child: OutlinedButton.icon(
                      onPressed: onRunAgain,
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('Run again'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
