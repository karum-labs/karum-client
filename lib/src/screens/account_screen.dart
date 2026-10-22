import 'package:flutter/material.dart';

import '../api/auth_models.dart';
import '../app/app_scope.dart';
import '../data/presets.dart';
import '../theme/brand_tokens.dart';
import '../widgets/common.dart';
import '../widgets/focus_ring.dart';
import '../widgets/karum_chrome.dart';

/// The signed-in home: the account and the campaigns seeded to it.
///
/// The landing screen stays the anonymous entry point. This route gives a
/// session somewhere to land, and the judge account a one-click path into the
/// four stored campaigns. Opening a campaign reads its newest run; it never
/// starts a paid scout.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.maybeOf(context);
    final session = scope?.session;
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 600 ? KarumSpacing.lg : KarumSpacing.page;

    return Scaffold(
      body: Column(
        children: [
          KarumHeader(
            onNewScout: () =>
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false),
            onStatus: () => Navigator.of(context).pushNamed('/status'),
          ),
          const JudgeBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal,
                vertical: KarumSpacing.xl2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: KarumLayout.contentMaxWidth,
                  ),
                  child: scope == null || session == null
                      ? const _SignedOutPane()
                      : _AccountPane(session: session),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPane extends StatelessWidget {
  const _AccountPane({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final account = session.account;
    final name = account.displayName.isEmpty
        ? account.email
        : account.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your account', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: KarumSpacing.sm),
        Text(
          'Your session and the campaigns attached to this account.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: palette.mute),
        ),
        const SizedBox(height: KarumSpacing.xl),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(KarumSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 30,
                  color: palette.brand,
                ),
                const SizedBox(width: KarumSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.email,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.mute),
                      ),
                    ],
                  ),
                ),
                if (account.isJudge)
                  const TagPill(label: 'Judge account', selected: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: KarumSpacing.xl2),
        const SectionLabel('Your campaigns'),
        const SizedBox(height: KarumSpacing.sm),
        Text(
          account.isJudge
              ? 'The four pre-seeded campaigns attached to the judge account. '
                    'Each opens its stored run; no new scout is started.'
              : 'Campaigns started while signed in belong to this account.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: palette.mute),
        ),
        const SizedBox(height: KarumSpacing.lg),
        if (account.isJudge) const _CampaignGrid() else const _EmptyCampaigns(),
        const SizedBox(height: KarumSpacing.xl),
        FocusRing(
          borderRadius: BorderRadius.circular(KarumRadius.control),
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Browse the public demo'),
          ),
        ),
      ],
    );
  }
}

class _CampaignGrid extends StatelessWidget {
  const _CampaignGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = KarumSpacing.lg;
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final preset in PresetCatalog.all)
              SizedBox(
                width: cardWidth,
                child: _CampaignCard(preset: preset),
              ),
          ],
        );
      },
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.preset});

  final KarumPreset preset;

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
                ModeChip(mode: preset.mode),
                const Spacer(),
                Text(
                  'Stored run',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.mute),
                ),
              ],
            ),
            const SizedBox(height: KarumSpacing.md),
            Text(
              preset.label,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: palette.ink),
            ),
            const SizedBox(height: KarumSpacing.xs),
            Text(
              '${preset.brand} · ${preset.city}',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.mute),
            ),
            const SizedBox(height: KarumSpacing.sm),
            Text(
              preset.description,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.mute),
            ),
            const SizedBox(height: KarumSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FocusRing(
                borderRadius: BorderRadius.circular(KarumRadius.control),
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .pushNamed('/campaigns/${preset.campaignId}'),
                  child: const Text('Open campaign'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCampaigns extends StatelessWidget {
  const _EmptyCampaigns();

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.travel_explore_rounded, size: 24, color: palette.mute),
            const SizedBox(height: KarumSpacing.md),
            Text(
              'No saved campaigns yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: KarumSpacing.xs),
            Text(
              'Start a scout from the landing page. The four public samples run '
              'without an account.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.mute),
            ),
            const SizedBox(height: KarumSpacing.lg),
            FocusRing(
              borderRadius: BorderRadius.circular(KarumRadius.control),
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (route) => false),
                child: const Text('Start a scout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedOutPane extends StatelessWidget {
  const _SignedOutPane();

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You are signed out.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: KarumSpacing.sm),
        Text(
          'Sign in to open the account page, or keep exploring the public demo.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: palette.mute),
        ),
        const SizedBox(height: KarumSpacing.xl),
        Wrap(
          spacing: KarumSpacing.sm,
          runSpacing: KarumSpacing.sm,
          children: [
            FocusRing(
              borderRadius: BorderRadius.circular(KarumRadius.control),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                child: const Text('Sign in'),
              ),
            ),
            FocusRing(
              borderRadius: BorderRadius.circular(KarumRadius.control),
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (route) => false),
                child: const Text('Browse the public demo'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
