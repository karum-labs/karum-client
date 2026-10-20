import 'dart:async';

import 'package:flutter/material.dart';

import '../api/gateway_client.dart';
import '../api/scout_models.dart';
import '../app/app_scope.dart';
import '../theme/brand_tokens.dart';
import '../util/file_saver.dart';
import '../widgets/async_states.dart';
import '../widgets/coach_overlay.dart';
import '../widgets/common.dart';
import '../widgets/door_board.dart';
import '../widgets/karum_chrome.dart';
import '../widgets/map_panel.dart';
import '../widgets/trace_panel.dart';

/// The scout workspace: live trace, map/list, and the door board.
///
/// A route can address a job (`/scout/:jobId`) or a stored campaign
/// (`/campaigns/:campaignId`). Running jobs stream SSE and fall back to polling
/// job status if the stream drops; restored campaigns render directly from the
/// stored payload.
class ScoutWorkspaceScreen extends StatefulWidget {
  const ScoutWorkspaceScreen({
    super.key,
    this.jobId,
    this.campaignId,
    this.showCoach = false,
  }) : assert(jobId != null || campaignId != null);

  final String? jobId;
  final String? campaignId;
  final bool showCoach;

  @override
  State<ScoutWorkspaceScreen> createState() => _ScoutWorkspaceScreenState();
}

class _ScoutWorkspaceScreenState extends State<ScoutWorkspaceScreen> {
  late GatewayClient _client;

  ScoutJob? _job;
  Campaign? _campaign;
  List<TraceEvent> _events = const [];
  bool _loading = true;
  String? _error;
  String? _streamError;
  String? _downloadError;
  bool _sseDropped = false;
  bool _polling = false;
  bool _canceling = false;
  bool _downloading = false;
  String? _regeneratingDoorId;
  int _pollFailures = 0;
  bool _refreshing = false;
  bool _coachShown = false;
  DateTime? _startedAt;
  Duration? _elapsed;
  Timer? _elapsedTimer;
  Timer? _pollTimer;
  StreamSubscription<TraceEvent>? _sseSub;

  String? get _effectiveJobId => widget.jobId ?? _campaign?.jobId;

  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = AppScope.maybeOf(context)?.client ?? GatewayClient();
    // `_client` comes from the inherited scope, so the first load can only run
    // once dependencies are available — not in initState.
    if (!_initialised) {
      _initialised = true;
      _load();
    }
  }

  /// Takes the keyboard focus when the route opens.
  ///
  /// The route that opened this one keeps the focus it had — the control the
  /// judge pressed. Flutter then deactivates that route, and a deactivated
  /// route's scope can no longer be traversed, so the keyboard is stuck: Tab
  /// walks a route that is no longer on screen and never reaches the board.
  ///
  /// Claiming the focus for this route puts the keyboard back where the judge
  /// is looking. The first Tab then lands on the first control in the
  /// workspace.
  void _claimFocus() {
    final scope = FocusScope.of(context);
    final current = FocusManager.instance.primaryFocus;
    if (current != null && current.nearestScope == scope) return;
    scope.requestFocus();
  }

  @override
  void dispose() {
    _stopLive();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.campaignId != null) {
        final campaign = await _client.fetchCampaign(widget.campaignId!);
        if (!mounted) return;
        setState(() {
          _applyCampaign(campaign);
          _loading = false;
        });
        _maybeShowCoach();
        return;
      }
      final job = await _client.fetchScout(widget.jobId!);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _applyJob(job);
      });
      _maybeShowCoach();
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
        _error = 'The campaign could not be restored: $error';
      });
    }
  }

  void _applyJob(ScoutJob job) {
    _job = job;
    _canceling = job.state == JobState.canceling;
    final campaign = job.campaign;
    if (campaign != null) {
      _applyCampaign(campaign);
      return;
    }
    if (job.state.isTerminal) {
      _stopLive();
      _error ??= job.errorMessage.isNotEmpty
          ? job.errorMessage
          : 'The job ended without a campaign payload.';
      return;
    }
    _startLive();
  }

  void _applyCampaign(Campaign campaign) {
    _campaign = campaign;
    _job = ScoutJob(
      jobId: campaign.jobId,
      campaignId: campaign.campaignId,
      state: campaign.state,
      errorCode: campaign.errorCode,
      errorMessage: campaign.errorMessage,
      campaign: campaign,
    );
    _events = List.unmodifiable(campaign.trace);
    _stopLive();
    if (campaign.state.isTerminal) {
      _startedAt = null;
      _elapsed = _events.isEmpty
          ? null
          : Duration(milliseconds: _events.last.elapsedMs);
    }
  }

  void _maybeShowCoach() {
    if (!widget.showCoach || _coachShown || _campaign == null) return;
    _coachShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showCoach(context);
    });
  }

  // ---------------------------------------------------------------------
  // Live updates
  // ---------------------------------------------------------------------

  void _startLive() {
    _startedAt ??= DateTime.now();
    _elapsedTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_startedAt!);
      });
    });
    _startPolling();
    _maybeSubscribe();
  }

  /// How long to wait before re-attaching a trace stream that dropped.
  ///
  /// The poll timer already refreshes job status every 1.5 seconds, so a
  /// dropped stream must not reconnect on every refresh — that would hammer
  /// the gateway with failing event requests for the life of the run.
  static const Duration _streamRetryInterval = Duration(seconds: 10);

  DateTime? _lastStreamAttempt;

  void _maybeSubscribe() {
    if (_sseSub != null) return;
    final id = _effectiveJobId;
    if (id == null) return;
    final now = DateTime.now();
    final last = _lastStreamAttempt;
    if (last != null && now.difference(last) < _streamRetryInterval) return;
    _lastStreamAttempt = now;
    _subscribe(id);
  }

  void _subscribe(String id) {
    final cursor = _events.isNotEmpty
        ? int.tryParse(_events.last.cursor) ?? 0
        : int.tryParse(_job?.traceCursor ?? '') ?? 0;
    _sseSub = _client
        .streamEvents(id, cursor: cursor)
        .listen(
          (event) {
            if (!mounted) return;
            setState(() {
              _sseDropped = false;
              _streamError = null;
              final last = _events.isEmpty ? null : _events.last;
              if (last == null || event.sequence != last.sequence) {
                _events = List.unmodifiable([..._events, event]);
              }
            });
          },
          onError: (Object error) {
            _sseSub = null;
            if (!mounted) return;
            setState(() {
              _sseDropped = true;
              _streamError = 'Trace stream dropped. Polling job status.';
            });
            _startPolling();
          },
          onDone: () {
            _sseSub = null;
            if (!mounted) return;
            _refreshJob();
          },
          cancelOnError: false,
        );
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    _polling = true;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _refreshJob();
    });
  }

  void _stopLive() {
    _sseSub?.cancel();
    _sseSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _polling = false;
  }

  Future<void> _refreshJob() async {
    final id = _effectiveJobId;
    if (id == null || _refreshing) return;
    _refreshing = true;
    try {
      final job = await _client.fetchScout(id);
      if (!mounted) return;
      setState(() {
        _pollFailures = 0;
        _applyJob(job);
      });
      _maybeShowCoach();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pollFailures += 1;
        if (_pollFailures >= 4) {
          _streamError =
              'Lost contact with the gateway. Showing the last known state.';
        }
      });
    } finally {
      _refreshing = false;
    }
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _cancel() async {
    final id = _effectiveJobId;
    if (id == null || _canceling) return;
    setState(() => _canceling = true);
    try {
      await _client.abortScout(id);
      if (!mounted) return;
      _startPolling();
    } on GatewayException catch (error) {
      if (!mounted) return;
      setState(() => _canceling = false);
      _snack(error.message);
    }
  }

  Future<void> _download() async {
    final campaign = _campaign;
    final id = _effectiveJobId;
    if (campaign == null || id == null || _downloading) return;
    final siteBrief = campaign.mode == ScoutMode.flagship;
    setState(() {
      _downloading = true;
      _downloadError = null;
    });
    try {
      final bytes = await _client.downloadDraft(id, siteBrief: siteBrief);
      await saveBytes(
        bytes,
        filename: siteBrief ? 'site-brief.pdf' : 'run-sheet.pdf',
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      _snack(
        siteBrief
            ? 'Site brief saved.'
            : 'Run-sheet saved with every stop and citation.',
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

  Future<void> _regenerate(Door door) async {
    final id = _effectiveJobId;
    if (id == null || _regeneratingDoorId != null) return;
    setState(() => _regeneratingDoorId = door.id);
    try {
      final campaign = await _client.regenerateDoorPitch(id, door.id);
      if (!mounted) return;
      setState(() {
        _applyCampaign(campaign);
        _regeneratingDoorId = null;
      });
    } on GatewayException catch (error) {
      if (!mounted) return;
      setState(() => _regeneratingDoorId = null);
      _snack(error.message);
    }
  }

  void _openDoor(Door door) {
    final id = _effectiveJobId;
    if (id == null) return;
    Navigator.of(context).pushNamed('/scout/$id/doors/${door.id}');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String get _elapsedLabel {
    final duration = _elapsed;
    if (duration == null) return '0.0s';
    final seconds = duration.inMilliseconds / 1000;
    return seconds < 10
        ? '${seconds.toStringAsFixed(1)}s'
        : '${seconds.round()}s';
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.maybeOf(context);
    final campaign = _campaign;
    // The focus is claimed after the frame so the route's scope is attached
    // and the board is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _claimFocus();
    });
    return Scaffold(
      body: Column(
        children: [
          KarumHeader(
            showBack: true,
            onNewScout: () =>
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false),
            onStatus: () => Navigator.of(context).pushNamed('/status'),
            actions: [
              NamedIconButton(
                label: campaign?.mode == ScoutMode.flagship
                    ? 'Download site brief'
                    : 'Download run-sheet',
                onPressed: campaign == null || _downloading ? null : _download,
                icon: Icons.picture_as_pdf_outlined,
                iconSize: 20,
                busy: _downloading,
              ),
            ],
          ),
          ModeBanner(health: scope?.health, error: scope?.healthError),
          const JudgeBanner(),
          _CampaignBar(
            campaign: campaign,
            job: _job,
            elapsedLabel: _elapsedLabel,
            canceling: _canceling,
            onCancel: _cancel,
          ),
          if (campaign?.state == JobState.degraded)
            NoticeBanner(
              title: 'Degraded run',
              message: campaign!.errorMessage.isNotEmpty
                  ? campaign.errorMessage
                  : 'An upstream dependency was unavailable. Some facts are '
                        'missing and the affected fields are labelled.',
              tone: NoticeTone.warning,
              icon: Icons.warning_amber_rounded,
            ),
          if (campaign?.state == JobState.failed)
            NoticeBanner(
              title: 'Run failed',
              message: campaign!.errorMessage.isNotEmpty
                  ? campaign.errorMessage
                  : 'The gateway ended this run with a failure code.',
              tone: NoticeTone.danger,
              icon: Icons.error_outline_rounded,
            ),
          if (_canceling && _job?.state != JobState.failed)
            const NoticeBanner(
              title: 'Abort requested',
              message:
                  'The gateway is stopping the pipeline. The last completed '
                  'stages remain on screen.',
              icon: Icons.cancel_outlined,
            ),
          if (_sseDropped && (_job?.isRunning ?? false))
            NoticeBanner(
              title: 'Trace stream dropped',
              message:
                  _streamError ??
                  'Polling job status every 1.5 seconds until the run ends.',
              tone: NoticeTone.warning,
              icon: Icons.wifi_tethering_off_rounded,
            ),
          if (_pollFailures >= 4)
            NoticeBanner(
              title: 'Gateway unreachable',
              message:
                  _streamError ??
                  'Showing the last known state. Retry when the gateway is '
                      'back.',
              tone: NoticeTone.danger,
              icon: Icons.cloud_off_rounded,
            ),
          if (_downloadError != null)
            NoticeBanner(
              title: 'Download failed',
              message: '$_downloadError The campaign is unchanged.',
              tone: NoticeTone.danger,
              icon: Icons.picture_as_pdf_outlined,
            ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _campaign == null) {
      return const LoadingState(label: 'Restoring the campaign…');
    }
    if (_error != null && _campaign == null) {
      return ErrorState(
        title: 'Campaign unavailable',
        message: _error!,
        onRetry: _load,
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) {
      return _desktopLayout();
    }
    return _tabbedLayout();
  }

  Widget _desktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 330,
          child: TracePanel(
            events: _events,
            state: _job?.state ?? JobState.unknown,
            sseDropped: _sseDropped,
            polling: _polling,
            error: _pollFailures >= 4 ? _streamError : null,
          ),
        ),
        VerticalDivider(width: 1, color: KarumPalette.of(context).line),
        Expanded(
          child: _campaign == null
              ? const _ScoutPlaceholder()
              : MapPanel(campaign: _campaign!, onOpenPitch: _openDoor),
        ),
        VerticalDivider(width: 1, color: KarumPalette.of(context).line),
        SizedBox(
          width: 450,
          child: _campaign == null
              ? const _BoardPlaceholder()
              : DoorBoard(
                  campaign: _campaign!,
                  onOpenPitch: _openDoor,
                  onRegenerate: _regenerate,
                  regeneratingDoorId: _regeneratingDoorId,
                ),
        ),
      ],
    );
  }

  Widget _tabbedLayout() {
    final palette = KarumPalette.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: palette.surface,
            child: TabBar(
              labelColor: palette.brand,
              unselectedLabelColor: palette.mute,
              indicatorColor: palette.brand,
              tabs: [
                Tab(text: 'Trace (${_events.length})'),
                const Tab(text: 'Map'),
                Tab(
                  text: _campaign == null
                      ? 'Board'
                      : 'Board (${_campaign!.doors.length})',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                TracePanel(
                  events: _events,
                  state: _job?.state ?? JobState.unknown,
                  sseDropped: _sseDropped,
                  polling: _polling,
                  error: _pollFailures >= 4 ? _streamError : null,
                ),
                _campaign == null
                    ? const _ScoutPlaceholder()
                    : MapPanel(campaign: _campaign!, onOpenPitch: _openDoor),
                _campaign == null
                    ? const _BoardPlaceholder()
                    : DoorBoard(
                        campaign: _campaign!,
                        onOpenPitch: _openDoor,
                        onRegenerate: _regenerate,
                        regeneratingDoorId: _regeneratingDoorId,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignBar extends StatelessWidget {
  const _CampaignBar({
    required this.campaign,
    required this.job,
    required this.elapsedLabel,
    required this.canceling,
    required this.onCancel,
  });

  final Campaign? campaign;
  final ScoutJob? job;
  final String elapsedLabel;
  final bool canceling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final running = job?.isRunning ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: KarumSpacing.xl,
        vertical: KarumSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            JobStatePill(state: job?.state ?? JobState.unknown),
            const SizedBox(width: KarumSpacing.sm),
            if (campaign != null) ...[
              ModeChip(mode: campaign!.mode),
              const SizedBox(width: KarumSpacing.sm),
            ],
            Text(
              campaign?.brand.name.isNotEmpty == true
                  ? campaign!.brand.name
                  : 'Resolving brand…',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: palette.ink),
            ),
            const SizedBox(width: KarumSpacing.sm),
            Icon(Icons.place_outlined, size: 15, color: palette.mute),
            const SizedBox(width: 4),
            Text(
              campaign?.city.isNotEmpty == true
                  ? campaign!.city
                  : 'Resolving city…',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.mute),
            ),
            if (campaign != null && campaign!.radiusMeters > 0) ...[
              const SizedBox(width: KarumSpacing.md),
              Text(
                '${(campaign!.radiusMeters / 1000).toStringAsFixed(1)} km',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.mute,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            const SizedBox(width: KarumSpacing.lg),
            Icon(Icons.timer_outlined, size: 15, color: palette.mute),
            const SizedBox(width: 4),
            Text(
              elapsedLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.mute,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (running) ...[
              const SizedBox(width: KarumSpacing.lg),
              TextButton.icon(
                onPressed: canceling ? null : onCancel,
                icon: const Icon(Icons.stop_circle_outlined, size: 17),
                label: Text(canceling ? 'Canceling…' : 'Cancel run'),
              ),
            ],
            if (campaign != null && campaign!.pointAttribution.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: KarumSpacing.md),
                child: Text(
                  campaign!.pointAttribution,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.mute),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoutPlaceholder extends StatelessWidget {
  const _ScoutPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const PanePlaceholder(
      icon: Icons.travel_explore_rounded,
      title: 'Scouting the city',
      message:
          'The map draws as soon as the gateway returns a point and door '
          'coordinates. Nothing is placed from guesswork.',
    );
  }
}

class _BoardPlaceholder extends StatelessWidget {
  const _BoardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const PanePlaceholder(
      icon: Icons.view_list_rounded,
      title: 'Ranking doors',
      message:
          'The board fills once scoring, enrichment, and pitching finish. '
          'Doors stay in the gateway order.',
    );
  }
}
