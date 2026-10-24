import 'package:flutter/material.dart';

import '../api/health_status.dart';
import '../api/scout_models.dart';
import '../app/app_scope.dart';
import '../theme/brand_tokens.dart';
import 'common.dart';
import 'focus_ring.dart';
import 'glossary.dart';
import 'karum_logo.dart';

/// The app header shared by every route.
///
/// The wordmark is the official lockup whenever the width allows it; below the
/// guide's 480 px breakpoint it collapses to the mark, exactly as the brand
/// guide specifies.
class KarumHeader extends StatelessWidget {
  const KarumHeader({
    super.key,
    this.showBack = false,
    this.actions = const [],
    this.onNewScout,
    this.onStatus,
    this.compact = false,
  });

  /// Whether to show the back affordance.
  final bool showBack;

  /// Route-specific trailing controls.
  final List<Widget> actions;

  /// Opens the seed builder. Hidden on narrow windows where the actions would
  /// crowd the mark.
  final VoidCallback? onNewScout;

  /// Opens the operational status page.
  final VoidCallback? onStatus;

  /// Uses the compact header height.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    return SafeArea(
      bottom: false,
      child: Container(
        height: compact ? 56 : 64,
        padding: EdgeInsets.symmetric(
          horizontal: width < 600 ? KarumSpacing.lg : KarumSpacing.xl2,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(bottom: BorderSide(color: palette.line)),
        ),
        child: Row(
          children: [
            if (showBack) ...[
              FocusRing(
                borderRadius: BorderRadius.circular(KarumRadius.control),
                child: NamedIconButton(
                  label: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icons.arrow_back_rounded,
                  iconSize: 20,
                ),
              ),
              const SizedBox(width: KarumSpacing.xs),
            ],
            FocusRing(
              borderRadius: BorderRadius.circular(KarumRadius.control),
              child: Semantics(
                label: 'Karum home',
                button: true,
                child: InkWell(
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/', (route) => false),
                  borderRadius: BorderRadius.circular(KarumRadius.control),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: KarumLogo(height: compact ? 24 : 28),
                  ),
                ),
              ),
            ),
            const Spacer(),
            // Built as a list, not a run of sibling `if`s, so the gap between
            // whichever of these actually render stays the same `sm` spacing
            // the custom [actions] already use below — three `if`s with no
            // separator between them left New scout, Glossary, and Status
            // touching with no gap at all.
            for (final (i, button) in _navButtons(context).indexed) ...[
              if (i > 0) const SizedBox(width: KarumSpacing.sm),
              button,
            ],
            for (final action in actions) ...[
              const SizedBox(width: KarumSpacing.sm),
              action,
            ],
          ],
        ),
      ),
    );
  }

  /// New scout, Glossary, and Status, in that order, filtered to whichever
  /// actually apply at this width — every one an icon-and-label button, so
  /// the row reads as one family of controls rather than two buttons with
  /// icons and one without. Below the 720 px nav breakpoint only Glossary
  /// keeps a presence, as an icon-only button.
  List<Widget> _navButtons(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hideNav = width < 720;
    return [
      if (!hideNav && onNewScout != null)
        FocusRing(
          borderRadius: BorderRadius.circular(KarumRadius.control),
          child: TextButton.icon(
            onPressed: onNewScout,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New scout'),
          ),
        ),
      // The glossary is reachable from every screen (PLAN.md §51). The full
      // label fits where the nav fits; on narrow windows an icon-only button
      // takes its place.
      if (!hideNav)
        FocusRing(
          borderRadius: BorderRadius.circular(KarumRadius.control),
          child: TextButton.icon(
            onPressed: () => showGlossarySheet(context),
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('Glossary'),
          ),
        )
      else
        FocusRing(
          borderRadius: BorderRadius.circular(KarumRadius.control),
          child: NamedIconButton(
            label: 'Glossary',
            onPressed: () => showGlossarySheet(context),
            icon: Icons.menu_book_rounded,
            iconSize: 20,
          ),
        ),
      if (!hideNav && onStatus != null)
        FocusRing(
          borderRadius: BorderRadius.circular(KarumRadius.control),
          child: TextButton.icon(
            onPressed: onStatus,
            icon: const Icon(Icons.monitor_heart_outlined, size: 18),
            label: const Text('Status'),
          ),
        ),
    ];
  }
}

/// The persistent fixture/degraded banner required by the honesty rules.
class ModeBanner extends StatelessWidget {
  const ModeBanner({super.key, required this.health, this.error});

  /// The health payload; null hides the banner.
  final HealthStatus? health;

  /// A health failure, rendered as an offline notice.
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final mode = health?.mode;
    if (error != null && mode == null) {
      return _Banner(
        background: palette.avoid.withValues(alpha: 0.14),
        foreground: palette.ink,
        icon: Icons.cloud_off_rounded,
        title: 'Gateway unavailable',
        message:
            'Karum cannot reach the gateway. Seed and campaign screens will '
            'explain what is missing rather than show invented results.',
      );
    }
    if (mode == null || mode == GatewayMode.live) {
      return const SizedBox.shrink();
    }
    return switch (mode) {
      GatewayMode.fixture => _Banner(
        background: palette.investigate.withValues(alpha: 0.14),
        foreground: palette.ink,
        icon: Icons.history_rounded,
        title: 'Showing a previous attempt',
        message:
            'These results were recorded from an earlier search and are shown '
            'as they were. They are not a fresh search of today\'s data.',
      ),
      GatewayMode.degraded => _Banner(
        background: palette.avoid.withValues(alpha: 0.14),
        foreground: palette.ink,
        icon: Icons.warning_amber_rounded,
        title: 'Degraded mode',
        message:
            'An upstream dependency is unavailable. The deterministic fallback '
            'is running and some facts may be missing.',
      ),
      GatewayMode.live => const SizedBox.shrink(),
    };
  }
}

/// A signed-in strip. It stays quiet for anonymous visitors, so the public
/// demo never grows a login wall. The hackathon judges banner lives on the
/// login screen and follows the SHOW_JUDGES_BANNER build flag.
class JudgeBanner extends StatelessWidget {
  const JudgeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final scope = AppScope.maybeOf(context);
    final session = scope?.session;
    if (scope == null || session == null) {
      return const SizedBox.shrink();
    }

    final name = session.account.displayName.isEmpty
        ? session.account.email
        : session.account.displayName;
    final detail = 'Signed in as $name. The public demo stays open.';
    return _Banner(
      background: palette.brand.withValues(alpha: 0.12),
      foreground: palette.ink,
      icon: Icons.verified_user_outlined,
      title: session.account.isJudge ? 'Judge mode' : 'Signed in',
      message: detail,
      action: TextButton(
        onPressed: () {
          scope.signOut();
        },
        child: const Text('Sign out'),
      ),
    );
  }
}

/// A campaign-local notice for degraded runs and warnings.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = NoticeTone.info,
  });

  final String title;
  final String message;
  final IconData icon;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final color = switch (tone) {
      NoticeTone.info => palette.brand,
      NoticeTone.warning => palette.investigate,
      NoticeTone.danger => palette.avoid,
    };
    return _Banner(
      background: color.withValues(alpha: 0.12),
      foreground: palette.ink,
      icon: icon,
      title: title,
      message: message,
    );
  }
}

/// The semantic tone of a [NoticeBanner].
enum NoticeTone { info, warning, danger }

class _Banner extends StatelessWidget {
  const _Banner({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(
        horizontal: KarumSpacing.xl,
        vertical: KarumSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: KarumSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title  ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  TextSpan(
                    text: message,
                    style: TextStyle(color: foreground.withValues(alpha: 0.82)),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: KarumSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A small state pill for a job.
class JobStatePill extends StatelessWidget {
  const JobStatePill({super.key, required this.state});

  final JobState state;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final color = switch (state) {
      JobState.ready => palette.brand,
      JobState.degraded => palette.investigate,
      JobState.failed => palette.avoid,
      JobState.running || JobState.resolving => palette.investigate,
      JobState.canceling => palette.mute,
      JobState.unknown => palette.mute,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KarumRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            state.label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.ink, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A bordered label for the mode of a campaign.
class ModeChip extends StatelessWidget {
  const ModeChip({super.key, required this.mode});

  final ScoutMode mode;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KarumRadius.pill),
        border: Border.all(color: palette.brand.withValues(alpha: 0.24)),
      ),
      child: Text(
        mode.shortLabel,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: palette.brand, fontWeight: FontWeight.w700),
      ),
    );
  }
}
