import 'package:flutter/material.dart';

import '../api/scout_models.dart';
import '../theme/brand_tokens.dart';
import 'common.dart';
import 'karum_chrome.dart';

/// The live pipeline trace. Events arrive in server order and are appended,
/// never re-sorted. The panel also exposes whether the SSE stream dropped and
/// polling is carrying the job.
class TracePanel extends StatefulWidget {
  const TracePanel({
    super.key,
    required this.events,
    required this.state,
    this.sseDropped = false,
    this.polling = false,
    this.error,
  });

  final List<TraceEvent> events;
  final JobState state;
  final bool sseDropped;
  final bool polling;
  final String? error;

  @override
  State<TracePanel> createState() => _TracePanelState();
}

class _TracePanelState extends State<TracePanel> {
  final ScrollController _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void didUpdateWidget(TracePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.events.length > _lastCount) {
      _lastCount = widget.events.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final target = _scroll.position.maxScrollExtent;
        // The guide's reduced-motion rule: keep the live trace pinned to the
        // newest stage without animating when the platform asks for it.
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          _scroll.jumpTo(target);
          return;
        }
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final live = !widget.state.isTerminal;
    return Container(
      color: palette.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KarumSpacing.xl,
              KarumSpacing.xl,
              KarumSpacing.xl,
              KarumSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: SectionLabel('Live trace')),
                    JobStatePill(state: widget.state),
                  ],
                ),
                const SizedBox(height: KarumSpacing.sm),
                Row(
                  children: [
                    Icon(
                      live ? Icons.sensors_rounded : Icons.check_circle_outline,
                      size: 14,
                      color: live ? palette.brand : palette.mute,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        live
                            ? (widget.sseDropped
                                  ? 'SSE dropped · polling status'
                                  : 'Streaming from the gateway')
                            : 'Run complete · trace frozen',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.mute),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.line),
          Expanded(
            child: widget.events.isEmpty
                ? PanePlaceholder(
                    icon: live ? Icons.hourglass_empty_rounded : Icons.route,
                    title: live
                        ? 'Waiting for the first hop'
                        : 'No trace events',
                    message: live
                        ? 'The pipeline writes each completed stage here.'
                        : 'This campaign arrived without a stored trace.',
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                      KarumSpacing.xl,
                      KarumSpacing.lg,
                      KarumSpacing.xl,
                      KarumSpacing.xl,
                    ),
                    itemCount: widget.events.length,
                    itemBuilder: (context, index) {
                      final event = widget.events[index];
                      final isLast = index == widget.events.length - 1;
                      return _TraceRow(
                        event: event,
                        isLast: isLast,
                        live: live && isLast,
                      );
                    },
                  ),
          ),
          if (widget.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(KarumSpacing.md),
              color: palette.avoid.withValues(alpha: 0.1),
              child: Text(
                widget.error!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.ink),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: KarumSpacing.xl,
              vertical: KarumSpacing.md,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.line)),
            ),
            child: Text(
              '${widget.events.length} stages · append-only · '
              '${widget.polling ? 'polling' : 'SSE'}',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.mute),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceRow extends StatelessWidget {
  const _TraceRow({
    required this.event,
    required this.isLast,
    required this.live,
  });

  final TraceEvent event;
  final bool isLast;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: live ? palette.brand : palette.mute,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1, color: palette.line)),
              ],
            ),
          ),
          const SizedBox(width: KarumSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: KarumSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.stageLabel,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: palette.ink),
                        ),
                      ),
                      Text(
                        event.elapsedLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.mute,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (event.detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.detail,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.mute),
                    ),
                  ],
                  if (event.cacheHit) ...[
                    const SizedBox(height: 4),
                    Text(
                      'cache hit',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.investigate,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
