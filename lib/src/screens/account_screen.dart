import 'package:flutter/material.dart';

import '../api/auth_models.dart';
import '../api/brand_profile.dart';
import '../api/gateway_client.dart';
import '../api/scout_models.dart';
import '../app/app_scope.dart';
import '../data/presets.dart';
import '../theme/brand_tokens.dart';
import '../widgets/async_states.dart';
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
        const SectionLabel('Your brand'),
        const SizedBox(height: KarumSpacing.sm),
        Text(
          'Every door pitch is written for this brand: what it is, why it wins, '
          'and who buys it.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: palette.mute),
        ),
        const SizedBox(height: KarumSpacing.lg),
        const _BrandProfileCard(),
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
    final scope = AppScope.maybeOf(context);
    final presets = scope?.presets?.all ?? const <KarumPreset>[];
    // The cards are the fetched catalogue, not hardcoded Dart constants
    // (PLAN.md §52), so the grid has its own loading and retry states.
    if (presets.isEmpty && scope?.presetsLoading == true) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: KarumSpacing.xl),
        child: LoadingState(label: 'Loading campaigns…'),
      );
    }
    if (presets.isEmpty && scope?.presetsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KarumSpacing.xl),
        child: ErrorState(
          title: 'Campaigns unavailable',
          message:
              'The gateway did not return the preset catalogue: '
              '${scope?.presetsError}',
          onRetry: scope?.refreshPresets,
        ),
      );
    }
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
            for (final preset in presets)
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
              'Start a search from the landing page. The four public previous '
              'runs work without an account; the result stays with the '
              'browser that started it.',
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

/// The account's brand profile: a summary with an Edit button that swaps in
/// the form.
class _BrandProfileCard extends StatefulWidget {
  const _BrandProfileCard();

  @override
  State<_BrandProfileCard> createState() => _BrandProfileCardState();
}

class _BrandProfileCardState extends State<_BrandProfileCard> {
  BrandProfile? _profile;
  String? _error;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  bool _initialised = false;

  final _name = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _positioning = TextEditingController();
  final _audience = TextEditingController();
  final _products = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _initialised = true;
      _load();
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _category,
      _description,
      _positioning,
      _audience,
      _products,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  GatewayClient? get _client => AppScope.maybeOf(context)?.client;

  Future<void> _load() async {
    final client = _client;
    if (client == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await client.fetchBrandProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        // An account with no brand yet goes straight to the form.
        _editing = !profile.saved;
      });
      _fill(profile);
    } on GatewayException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  void _fill(BrandProfile profile) {
    _name.text = profile.name;
    _category.text = profile.category;
    _description.text = profile.description;
    _positioning.text = profile.positioning;
    _audience.text = profile.audience;
    _products.text = profile.skus.map((sku) => sku.name).join('\n');
  }

  Future<void> _save() async {
    final client = _client;
    if (client == null || _saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the brand a name.');
      return;
    }
    final existing = {
      for (final sku in _profile?.skus ?? const <Sku>[]) sku.name: sku.id,
    };
    final products = _products.text
        .split(RegExp(r'[\n,]'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .map((name) => Sku(id: existing[name] ?? '', name: name))
        .toList(growable: false);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await client.saveBrandProfile(
        BrandProfile(
          name: _name.text.trim(),
          category: _category.text.trim(),
          description: _description.text.trim(),
          positioning: _positioning.text.trim(),
          audience: _audience.text.trim(),
          skus: products,
        ),
      );
      if (!mounted) return;
      setState(() {
        _profile = saved;
        _saving = false;
        _editing = false;
      });
      _fill(saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brand saved. New pitches use it.')),
      );
    } on GatewayException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.xl),
        child: _loading
            ? const LoadingState(label: 'Loading your brand…')
            : _editing
            ? _form(context)
            : _summary(context),
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final palette = KarumPalette.of(context);
    final profile = _profile ?? const BrandProfile();
    Widget row(String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: KarumSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: palette.mute),
            ),
            const SizedBox(height: 2),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_drink_outlined, color: palette.brand),
            const SizedBox(width: KarumSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (profile.category.isNotEmpty)
                    Text(
                      profile.category,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.mute),
                    ),
                ],
              ),
            ),
            FocusRing(
              borderRadius: BorderRadius.circular(KarumRadius.control),
              child: OutlinedButton.icon(
                key: const Key('brand-edit'),
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit brand'),
              ),
            ),
          ],
        ),
        row('About the brand', profile.description),
        row('Why it wins', profile.positioning),
        row('Who buys it', profile.audience),
        if (profile.skus.isNotEmpty) ...[
          const SizedBox(height: KarumSpacing.md),
          Wrap(
            spacing: KarumSpacing.sm,
            runSpacing: KarumSpacing.sm,
            children: [
              for (final sku in profile.skus) TagPill(label: sku.name),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: KarumSpacing.md),
          Text(_error!, style: TextStyle(color: palette.avoid)),
        ],
      ],
    );
  }

  Widget _form(BuildContext context) {
    final palette = KarumPalette.of(context);
    Widget field(
      TextEditingController controller,
      String label,
      String hint, {
      int maxLines = 1,
      int maxLength = 600,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: KarumSpacing.md),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: 1,
          maxLength: maxLength,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field(_name, 'Brand name', 'e.g. Bloom Soda Co.', maxLength: 120),
        field(_category, 'What kind of brand', 'e.g. Craft soft drinks'),
        field(
          _description,
          'About the brand',
          'What you make and how venues serve it',
          maxLines: 3,
        ),
        field(
          _positioning,
          'Why it wins',
          'What sets you apart, and what a venue gains by stocking you',
          maxLines: 3,
        ),
        field(
          _audience,
          'Who buys it',
          'The guests and venues the brand is for',
          maxLines: 2,
        ),
        field(
          _products,
          'Products',
          'One per line',
          maxLines: 5,
          maxLength: 1600,
        ),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: palette.avoid)),
          const SizedBox(height: KarumSpacing.md),
        ],
        Row(
          children: [
            FocusRing(
              borderRadius: BorderRadius.circular(KarumRadius.control),
              child: FilledButton.icon(
                key: const Key('brand-save'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save brand'),
              ),
            ),
            if (_profile?.saved == true) ...[
              const SizedBox(width: KarumSpacing.sm),
              TextButton(
                onPressed: _saving
                    ? null
                    : () {
                        _fill(_profile!);
                        setState(() {
                          _editing = false;
                          _error = null;
                        });
                      },
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
