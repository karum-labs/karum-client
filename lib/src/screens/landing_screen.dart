import 'dart:math';

import 'package:flutter/material.dart';

import '../api/gateway_client.dart';
import '../api/scout_models.dart';
import '../api/scout_request.dart';
import '../app/app_scope.dart';
import '../app/coach_gate.dart';
import '../app/routes.dart';
import '../data/presets.dart';
import '../theme/brand_tokens.dart';
import '../util/preset_runs.dart';
import '../widgets/async_states.dart';
import '../widgets/common.dart';
import '../widgets/focus_ring.dart';
import '../widgets/karum_chrome.dart';

/// The landing page and free-entry seed builder.
///
/// The preset cards are the three-minute judge path: one click posts a locked
/// body, while the form runs the same pipeline for a seed the operator builds.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _builderKey = GlobalKey();
  final GlobalKey _presetsKey = GlobalKey();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _brand = TextEditingController();
  final TextEditingController _vibe = TextEditingController();
  final TextEditingController _sku = TextEditingController();
  final List<SeedEntity> _seeds = [];
  final List<String> _fallbacks = [];
  final List<Sku> _skus = [];
  final Set<String> _tags = {'urn:tag:genre:place:restaurant:bar'};

  late GatewayClient _client;
  ScoutMode _mode = ScoutMode.wholesale;
  int _radiusMeters = 8000;
  String _brandQuery = '';
  bool _submitting = false;
  String? _error;
  List<CityCandidate> _candidates = const [];
  String? _idempotencyKey;

  /// The point that came with a previous run loaded by "Inspect this seed". It lets
  /// it run without a geocoder key; editing the city clears it.
  GeoPoint? _presetPoint;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = AppScope.maybeOf(context)?.client ?? GatewayClient();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _city.dispose();
    _brand.dispose();
    _vibe.dispose();
    _sku.dispose();
    super.dispose();
  }

  void _markDirty() {
    _idempotencyKey = null;
    _error = null;
    _candidates = const [];
  }

  /// True once anything in the free-entry form differs from its blank,
  /// just-loaded state — including text typed but not yet turned into a
  /// seed/SKU chip. Drives whether the Clear button next to "Run this
  /// scout" is shown at all.
  bool get _hasFreeEntryInput =>
      _city.text.isNotEmpty ||
      _brand.text.isNotEmpty ||
      _vibe.text.isNotEmpty ||
      _sku.text.isNotEmpty ||
      _seeds.isNotEmpty ||
      _fallbacks.isNotEmpty ||
      _skus.isNotEmpty ||
      _brandQuery.isNotEmpty ||
      _mode != ScoutMode.wholesale ||
      _radiusMeters != 8000 ||
      _presetPoint != null ||
      !(_tags.length == 1 &&
          _tags.contains('urn:tag:genre:place:restaurant:bar'));

  /// Resets the free-entry form to the state it loads in. A "locked
  /// previous run" loaded with "Inspect this seed" counts as input too, so
  /// Clear also undoes that.
  void _clearFreeEntry() {
    setState(() {
      _city.clear();
      _brand.clear();
      _vibe.clear();
      _sku.clear();
      _seeds.clear();
      _fallbacks.clear();
      _skus.clear();
      _tags
        ..clear()
        ..add('urn:tag:genre:place:restaurant:bar');
      _mode = ScoutMode.wholesale;
      _radiusMeters = 8000;
      _brandQuery = '';
      _presetPoint = null;
      _markDirty();
    });
  }

  void _scrollToBuilder() {
    final target = _builderKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.04,
      );
    }
  }

  /// "Try now": sign in as the judge and open the account page, which lists
  /// the stored campaigns. An existing session just goes there.
  Future<void> _tryNow() async {
    if (_submitting) return;
    final scope = AppScope.maybeOf(context);
    if (scope == null) {
      setState(() => _error = 'Demo access is unavailable in this build.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (scope.session == null) await scope.judgeSignIn();
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/account', (route) => false);
    } on GatewayException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Demo access failed. Try signing in instead.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Whether the "Start from a previous run" cards show on the landing page.
  static const bool _showPresetSection = false;

  // ignore: unused_element -- kept for when the preset section comes back.
  void _scrollToPresets() {
    final target = _presetsKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.04,
      );
    }
  }

  void _loadPresetIntoBuilder(KarumPreset preset) {
    setState(() {
      _mode = preset.mode;
      _city.text = preset.city;
      _brand.text = preset.brand;
      _seeds
        ..clear()
        ..addAll(preset.seeds);
      _skus
        ..clear()
        ..addAll(preset.skus);
      _fallbacks.clear();
      _brandQuery = '';
      _tags
        ..clear()
        ..addAll(preset.categoryTags);
      _radiusMeters = preset.radiusMeters;
      _presetPoint = preset.point;
      _markDirty();
    });
    _scrollToBuilder();
  }

  Future<void> _launchPreset(KarumPreset preset) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
      _candidates = const [];
    });
    try {
      // Reopening a preset shows the stored run; only the workspace's
      // "Run again" starts a fresh one. Signed-in callers get their own run
      // back from the gateway; an anonymous visitor's run is remembered here.
      final anonymous = AppScope.maybeOf(context)?.session == null;
      final remembered = anonymous ? readPresetRun(preset.id) : null;
      if (remembered != null) {
        try {
          final previous = await _client.fetchScout(remembered);
          if (!mounted) return;
          if (previous.state != JobState.failed) {
            _openJob(previous, coach: true);
            return;
          }
        } on GatewayException {
          // The run is gone (a reset store); fall through to a new one.
        }
        writePresetRun(preset.id, null);
      }
      final job = await _client.createScout(
        ScoutRequest.preset(preset.id),
        idempotencyKey: _newKey(),
      );
      if (anonymous) writePresetRun(preset.id, job.jobId);
      if (!mounted) return;
      _openJob(job, coach: true);
    } on GatewayException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'The scout could not start: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitFreeEntry({GeoPoint? point}) async {
    if (_submitting) return;
    final validation = _validate();
    if (validation != null) {
      setState(() {
        _error = validation;
        _candidates = const [];
      });
      return;
    }

    final request = _buildRequest(point: point);
    setState(() {
      _submitting = true;
      _error = null;
      _candidates = const [];
    });
    try {
      final job = await _client.createScout(
        request,
        idempotencyKey: _idempotencyKey ??= _newKey(),
      );
      if (!mounted) return;
      _openJob(job);
    } on GatewayException catch (error) {
      if (!mounted) return;
      if (error.isAmbiguous) {
        setState(() => _candidates = error.candidates);
        final chosen = await _chooseCity(error.candidates);
        if (!mounted) return;
        if (chosen != null) {
          setState(() => _submitting = false);
          await _submitFreeEntry(point: chosen);
          return;
        }
      }
      setState(() {
        _error = error.message;
        _candidates = error.isAmbiguous ? error.candidates : const [];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'The scout could not start: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openJob(ScoutJob job, {bool coach = false}) {
    if (job.jobId.isEmpty) {
      setState(() => _error = 'The gateway returned no job id.');
      return;
    }
    final showCoach = coach && CoachGate.consume();
    Navigator.of(context).pushNamed(
      '/scout/${job.jobId}',
      arguments: WorkspaceArgs(showCoach: showCoach),
    );
  }

  ScoutRequest _buildRequest({GeoPoint? point}) {
    return ScoutRequest.freeEntry(
      city: _city.text.trim(),
      mode: _mode,
      radiusMeters: _radiusMeters,
      brandName: _brand.text.trim().isEmpty && _seeds.isEmpty
          ? ''
          : _brand.text.trim(),
      skus: List.unmodifiable(_skus),
      seedEntities: List.unmodifiable(_seeds),
      brandQuery: _brandQuery,
      fallbackQueries: List.unmodifiable(_fallbacks),
      categoryTags: List.unmodifiable(_tags),
      point: point ?? _presetPoint,
    );
  }

  String? _validate() {
    if (_city.text.trim().isEmpty) {
      return 'Add a city before running the scout.';
    }
    if (_city.text.trim().length > 200) {
      return 'The city must be 200 characters or fewer.';
    }
    if (_radiusMeters < 500 || _radiusMeters > 50000) {
      return 'The radius must be between 0.5 and 50 km.';
    }
    if (_brand.text.trim().length > 200) {
      return 'The brand name must be 200 characters or fewer.';
    }
    if (_brandQuery.length > 200) {
      return 'The brand query must be 200 characters or fewer.';
    }
    if (_fallbacks.any((v) => v.length > 200)) {
      return 'Each vibe must be 200 characters or fewer.';
    }
    if (_skus.length > 24) return 'The SKU list is capped at 24 items.';
    if (_skus.any((sku) => sku.name.length > 200)) {
      return 'Each SKU name must be 200 characters or fewer.';
    }
    final seedCount =
        _seeds.length + (_brandQuery.isEmpty ? 0 : 1) + _fallbacks.length;
    if (seedCount == 0) {
      return 'Add at least one confirmed entity, a brand search, or a vibe.';
    }
    if (seedCount > 4) {
      return 'The seed composite can contain at most four entities.';
    }
    return null;
  }

  Future<GeoPoint?> _chooseCity(List<CityCandidate> candidates) {
    return showDialog<GeoPoint>(
      context: context,
      builder: (context) {
        final palette = KarumPalette.of(context);
        return AlertDialog(
          title: const Text('Which city did you mean?'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The gateway found more than one match. Pick the point the '
                  'scout should use.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: palette.mute),
                ),
                const SizedBox(height: KarumSpacing.md),
                for (final candidate in candidates)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.place_outlined, color: palette.brand),
                    title: Text(
                      candidate.formattedAddress.isEmpty
                          ? 'Unnamed candidate'
                          : candidate.formattedAddress,
                    ),
                    subtitle: Text(
                      '${candidate.point.lat.toStringAsFixed(4)}, '
                      '${candidate.point.lng.toStringAsFixed(4)}',
                    ),
                    onTap: () => Navigator.of(context).pop(candidate.point),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep editing'),
            ),
          ],
        );
      },
    );
  }

  void _addSeed(KnownSeed known) {
    if (_seeds.any((seed) => seed.id == known.entity.id)) return;
    if (_totalSeeds >= 4) {
      setState(
        () => _error = 'The seed composite is already at four entities.',
      );
      return;
    }
    setState(() {
      _seeds.add(known.entity);
      _brand.text = known.entity.name;
      _markDirty();
    });
  }

  void _commitBrandQuery() {
    final query = _brand.text.trim();
    if (query.isEmpty) return;
    if (_seeds.any((seed) => seed.name.toLowerCase() == query.toLowerCase())) {
      return;
    }
    if (_totalSeeds >= 4) {
      setState(
        () => _error = 'The seed composite is already at four entities.',
      );
      return;
    }
    setState(() {
      _brandQuery = query;
      _markDirty();
    });
  }

  void _addFallback() {
    final value = _vibe.text.trim();
    if (value.isEmpty) return;
    if (value.length > 200) {
      setState(() => _error = 'Each vibe must be 200 characters or fewer.');
      return;
    }
    if (_totalSeeds >= 4) {
      setState(
        () => _error = 'The seed composite can contain at most four entities.',
      );
      return;
    }
    if (_fallbacks.any((item) => item.toLowerCase() == value.toLowerCase())) {
      _vibe.clear();
      return;
    }
    setState(() {
      _fallbacks.add(value);
      _vibe.clear();
      _markDirty();
    });
  }

  void _addSku() {
    final value = _sku.text.trim();
    if (value.isEmpty) return;
    if (_skus.length >= 24) {
      setState(() => _error = 'The SKU list is capped at 24 items.');
      return;
    }
    if (value.length > 200) {
      setState(() => _error = 'Each SKU name must be 200 characters or fewer.');
      return;
    }
    setState(() {
      _skus.add(
        Sku(
          id: value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
          name: value,
        ),
      );
      _sku.clear();
      _markDirty();
    });
  }

  int get _totalSeeds =>
      _seeds.length + (_brandQuery.isEmpty ? 0 : 1) + _fallbacks.length;

  String _newKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    // Keep the bound below 2^32: the browser implementation of `nextInt`
    // throws a RangeError at 1 << 32, which the VM tolerates.
    final salt = Random.secure().nextInt(1 << 31).toRadixString(16);
    return 'karum-$now-$salt';
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.maybeOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 600 ? KarumSpacing.lg : KarumSpacing.page;
    final contentWidth = width > 1280 ? 1200.0 : width;

    return Scaffold(
      body: Column(
        children: [
          KarumHeader(
            onNewScout: _scrollToBuilder,
            onStatus: () => Navigator.of(context).pushNamed('/status'),
            actions: [
              // The public demo stays anonymous by default; the header only
              // offers the optional account path. Once a session exists the
              // same entry opens the account page instead of the login form.
              FocusRing(
                borderRadius: BorderRadius.circular(KarumRadius.control),
                child: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(scope?.session == null ? '/login' : '/account'),
                  child: Text(
                    scope?.session == null ? 'Sign in' : 'Your account',
                  ),
                ),
              ),
            ],
          ),
          ModeBanner(health: scope?.health, error: scope?.healthError),
          const JudgeBanner(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      width < 600 ? KarumSpacing.xl : 56,
                      horizontal,
                      KarumSpacing.page,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Hero(
                          compact: width < 900,
                          onTryNow: _tryNow,
                          onNewScout: _scrollToBuilder,
                          presets: scope?.presets,
                        ),
                        const SizedBox(height: 52),
                        // The "judge path, one click away" section is hidden
                        // for now; flip this to bring it back.
                        if (_showPresetSection) ...[
                          _buildPresetSection(width, scope),
                          const SizedBox(height: 52),
                        ],
                        _buildBuilder(context, width),
                        const SizedBox(height: KarumSpacing.page),
                        _Footer(
                          onStatus: () =>
                              Navigator.of(context).pushNamed('/status'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetSection(double width, AppScope? scope) {
    final groups = scope?.presets?.groups ?? const <PresetGroup>[];
    return Column(
      key: _presetsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Start from a previous run'),
        const SizedBox(height: KarumSpacing.sm),
        Text(
          'The judge path, one click away.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: KarumSpacing.xs),
        Text(
          'Each one posts a stored city, seed (the brand and the taste '
          'words that describe it), radius, and category tag. No typing, no '
          'geocoder miss. Each click runs it as its own search; the result '
          'stays with this browser.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: KarumPalette.of(context).mute),
        ),
        const SizedBox(height: KarumSpacing.xl),
        // The cards are read from `GET /api/v1/presets`, not hardcoded
        // (PLAN.md §52), so the section has its own loading and retry states
        // rather than always-on constants.
        if (groups.isEmpty && scope?.presetsLoading == true)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: KarumSpacing.xl),
            child: LoadingState(label: 'Loading previous runs…'),
          )
        else if (groups.isEmpty && scope?.presetsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KarumSpacing.xl),
            child: ErrorState(
              title: 'Previous runs unavailable',
              message:
                  'The gateway did not return the previous-run catalogue: '
                  '${scope?.presetsError}',
              onRetry: scope?.refreshPresets,
            ),
          )
        else if (width >= 1000)
          // IntrinsicHeight stretches every card to the tallest one's natural
          // height (the two-button Brooklyn card), so the row reads as one
          // even shelf instead of three cards of different heights. Each
          // card absorbs the extra space with its own Spacer so the button
          // block still lands at the same baseline on every card.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < groups.length; i++) ...[
                  if (i > 0) const SizedBox(width: KarumSpacing.lg),
                  Expanded(
                    child: _PresetCard(
                      index: i,
                      group: groups[i],
                      disabled: _submitting,
                      onRun: _launchPreset,
                      onInspect: _loadPresetIntoBuilder,
                      equalizeHeight: true,
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < groups.length; i++) ...[
                if (i > 0) const SizedBox(height: KarumSpacing.lg),
                _PresetCard(
                  index: i,
                  group: groups[i],
                  disabled: _submitting,
                  onRun: _launchPreset,
                  onInspect: _loadPresetIntoBuilder,
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildBuilder(BuildContext context, double width) {
    final palette = KarumPalette.of(context);
    final compact = width < 760;
    final suggestions = _brandSuggestions;
    return Card(
      key: _builderKey,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(compact ? KarumSpacing.xl : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Free entry'),
                      const SizedBox(height: KarumSpacing.sm),
                      Text(
                        'Build a search instead.',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: KarumSpacing.xs),
                      Text(
                        'Enter a brand (the seed) and a city. Out comes a '
                        'ranked list of places to visit (the door board), the '
                        'evidence behind each one, and a short pitch.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: palette.mute),
                      ),
                    ],
                  ),
                ),
                if (!compact)
                  FormulaBadge(
                    formula: 'S_door = 0.50 · A_taste + 0.30 · O_shelf + 0.20 · D_demo',
                  ),
              ],
            ),
            const SizedBox(height: KarumSpacing.xl),
            const SectionLabel('Mode'),
            const SizedBox(height: KarumSpacing.sm),
            Wrap(
              spacing: KarumSpacing.sm,
              runSpacing: KarumSpacing.sm,
              children: [
                for (final mode in ScoutMode.values)
                  FocusRing(
                    borderRadius: BorderRadius.circular(KarumRadius.pill),
                    child: ChoiceChip(
                      label: Text(mode.label),
                      selected: _mode == mode,
                      onSelected: _submitting
                          ? null
                          : (_) => setState(() {
                              _mode = mode;
                              _markDirty();
                            }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: KarumSpacing.xl),
            if (compact) ...[
              _cityField(),
              const SizedBox(height: KarumSpacing.lg),
              _radiusField(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _cityField()),
                  const SizedBox(width: KarumSpacing.lg),
                  Expanded(flex: 4, child: _radiusField()),
                ],
              ),
            const SizedBox(height: KarumSpacing.xl),
            _brandField(suggestions),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: KarumSpacing.sm),
              _suggestionList(suggestions),
            ],
            if (_seeds.isNotEmpty || _brandQuery.isNotEmpty) ...[
              const SizedBox(height: KarumSpacing.md),
              Wrap(
                spacing: KarumSpacing.sm,
                runSpacing: KarumSpacing.sm,
                children: [
                  for (final seed in _seeds)
                    InputChip(
                      avatar: Icon(
                        seed.kind == 'brand'
                            ? Icons.storefront_outlined
                            : Icons.place_outlined,
                        size: 16,
                      ),
                      label: Text(seed.name),
                      onDeleted: _submitting
                          ? null
                          : () => setState(() {
                              _seeds.remove(seed);
                              _markDirty();
                            }),
                    ),
                  if (_brandQuery.isNotEmpty)
                    InputChip(
                      avatar: const Icon(Icons.search_rounded, size: 16),
                      label: Text('Qloo search: $_brandQuery'),
                      onDeleted: _submitting
                          ? null
                          : () => setState(() {
                              _brandQuery = '';
                              _markDirty();
                            }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: KarumSpacing.xl),
            _vibeField(),
            if (_fallbacks.isNotEmpty) ...[
              const SizedBox(height: KarumSpacing.md),
              Wrap(
                spacing: KarumSpacing.sm,
                runSpacing: KarumSpacing.sm,
                children: [
                  for (final vibe in _fallbacks)
                    InputChip(
                      label: Text(vibe),
                      onDeleted: _submitting
                          ? null
                          : () => setState(() {
                              _fallbacks.remove(vibe);
                              _markDirty();
                            }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: KarumSpacing.xl),
            _skuField(),
            if (_skus.isNotEmpty) ...[
              const SizedBox(height: KarumSpacing.md),
              Wrap(
                spacing: KarumSpacing.sm,
                runSpacing: KarumSpacing.sm,
                children: [
                  for (final sku in _skus)
                    InputChip(
                      avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: Text(sku.name),
                      onDeleted: _submitting
                          ? null
                          : () => setState(() {
                              _skus.remove(sku);
                              _markDirty();
                            }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: KarumSpacing.xl),
            const SectionLabel('Door category'),
            const SizedBox(height: KarumSpacing.sm),
            Wrap(
              spacing: KarumSpacing.sm,
              runSpacing: KarumSpacing.sm,
              children: [
                for (final option in PresetCatalog.categoryTags)
                  FocusRing(
                    borderRadius: BorderRadius.circular(KarumRadius.pill),
                    child: FilterChip(
                      label: Text(option.label),
                      selected: _tags.contains(option.urn),
                      onSelected: _submitting
                          ? null
                          : (selected) => setState(() {
                              if (selected) {
                                _tags.add(option.urn);
                              } else {
                                _tags.remove(option.urn);
                              }
                              _markDirty();
                            }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: KarumSpacing.xl),
            if (_error != null) ...[
              _ErrorNote(
                message: _error!,
                candidates: _candidates,
                onCandidate: _submitting
                    ? null
                    : (candidate) => _submitFreeEntry(point: candidate.point),
              ),
              const SizedBox(height: KarumSpacing.lg),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final note = Text(
                  'Scores are Qloo associations, not foot traffic. '
                  'Places facts and menu citations stay labelled.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.mute),
                );
                final submit = FocusRing(
                  borderRadius: BorderRadius.circular(KarumRadius.control),
                  child: FilledButton.icon(
                    key: const Key('free-entry-submit'),
                    onPressed: _submitting ? null : _submitFreeEntry,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(_submitting ? 'Starting…' : 'Run this scout'),
                  ),
                );
                // Only shown once the form has something to clear, and a
                // Wrap rather than a fixed Row: at narrow widths "Clear" and
                // "Run this scout" wrap onto their own line instead of
                // overflowing it.
                final submitGroup = Wrap(
                  spacing: KarumSpacing.sm,
                  runSpacing: KarumSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_hasFreeEntryInput)
                      FocusRing(
                        borderRadius: BorderRadius.circular(
                          KarumRadius.control,
                        ),
                        child: OutlinedButton(
                          onPressed: _submitting ? null : _clearFreeEntry,
                          child: const Text('Clear'),
                        ),
                      ),
                    submit,
                  ],
                );
                // Below the official 480 px breakpoint the button drops onto
                // its own line: side by side, the pair overflows a phone
                // column instead of wrapping.
                if (constraints.maxWidth < KarumLayout.markOnlyBelow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      note,
                      const SizedBox(height: KarumSpacing.md),
                      submitGroup,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: note),
                    const SizedBox(width: KarumSpacing.lg),
                    submitGroup,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityField() {
    return TextField(
      controller: _city,
      enabled: !_submitting,
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {
        // A typed city no longer matches the previous run's stored point.
        _presetPoint = null;
        _markDirty();
      }),
      decoration: const InputDecoration(
        labelText: 'City',
        hintText: 'Austin, TX, US',
        prefixIcon: Icon(Icons.location_city_outlined),
        helperText: 'Type a city. Ambiguous matches ask you to choose a point.',
      ),
    );
  }

  Widget _radiusField() {
    final palette = KarumPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Search radius',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: palette.ink),
              ),
            ),
            Text(
              '${(_radiusMeters / 1000).toStringAsFixed(1)} km',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: palette.brand,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(
          value: _radiusMeters.toDouble(),
          min: 500,
          max: 50000,
          divisions: 99,
          label: '${(_radiusMeters / 1000).toStringAsFixed(1)} km',
          onChanged: _submitting
              ? null
              : (value) => setState(() {
                  _radiusMeters = value.round();
                  _markDirty();
                }),
        ),
        Text(
          'The server caps the radius at 50 km.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: palette.mute),
        ),
      ],
    );
  }

  Widget _brandField(List<KnownSeed> suggestions) {
    return TextField(
      controller: _brand,
      enabled: !_submitting,
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(_markDirty),
      onSubmitted: (_) => _commitBrandQuery(),
      decoration: InputDecoration(
        labelText: 'Brand or seed entity',
        hintText: 'Muji, Aesop, Subko…',
        prefixIcon: const Icon(Icons.travel_explore_rounded),
        helperText:
            'Known entities resolve locally. An unknown brand is sent as a '
            'Qloo search, never invented as an id.',
        suffixIcon: NamedIconButton(
          label: 'Search for the typed brand',
          tooltip: 'Use the typed brand as a search',
          onPressed: _submitting ? null : _commitBrandQuery,
          icon: Icons.search_rounded,
        ),
      ),
    );
  }

  List<KnownSeed> get _brandSuggestions {
    if (_brand.text.trim().length < 2 || _seeds.length >= 4) return const [];
    final known = AppScope.maybeOf(context)?.presets?.knownSeeds ?? const [];
    return known
        .where((entry) => entry.matches(_brand.text))
        .where((entry) => !_seeds.any((seed) => seed.id == entry.entity.id))
        .take(4)
        .toList(growable: false);
  }

  Widget _suggestionList(List<KnownSeed> suggestions) {
    final palette = KarumPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(KarumRadius.control),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          for (final known in suggestions)
            ListTile(
              dense: true,
              leading: Icon(
                known.entity.kind == 'brand'
                    ? Icons.storefront_outlined
                    : Icons.place_outlined,
                size: 18,
                color: palette.brand,
              ),
              title: Text(known.entity.name),
              subtitle: Text('${known.entity.kind} · ${known.city}'),
              trailing: const Icon(Icons.add_rounded, size: 18),
              onTap: _submitting ? null : () => _addSeed(known),
            ),
        ],
      ),
    );
  }

  Widget _vibeField() {
    return TextField(
      controller: _vibe,
      enabled: !_submitting,
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(_markDirty),
      onSubmitted: (_) => _addFallback(),
      decoration: InputDecoration(
        labelText: 'Vibe chips',
        hintText: 'matcha, ceramics studio, minimal homeware…',
        prefixIcon: const Icon(Icons.auto_awesome_outlined),
        helperText:
            '$_totalSeeds/4 entities. Vibe chips form a composite seed.',
        suffixIcon: NamedIconButton(
          label: 'Add this vibe',
          onPressed: _submitting ? null : _addFallback,
          icon: Icons.add_rounded,
        ),
      ),
    );
  }

  Widget _skuField() {
    return TextField(
      controller: _sku,
      enabled: !_submitting,
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(_markDirty),
      onSubmitted: (_) => _addSku(),
      decoration: InputDecoration(
        labelText: 'Brand SKUs',
        hintText: 'Sola Yuzu-Mezcal Aperitif',
        prefixIcon: const Icon(Icons.inventory_2_outlined),
        helperText: '${_skus.length}/24. The pitch chooses one SKU.',
        suffixIcon: NamedIconButton(
          label: 'Add this SKU',
          onPressed: _submitting ? null : _addSku,
          icon: Icons.add_rounded,
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.compact,
    required this.onTryNow,
    required this.onNewScout,
    required this.presets,
  });

  final bool compact;

  /// "Try now" — signs in as the judge and opens the account page.
  final VoidCallback onTryNow;

  /// "New scout" — jumps to the free-entry builder ("Build a search
  /// instead."), matching the header's own "New scout" action.
  final VoidCallback onNewScout;

  /// The fetched previous-run catalogue, or null while it is still loading.
  /// The proof strip renders nothing rather than a stale, hardcoded list
  /// while it waits (PLAN.md §52).
  final PresetCatalog? presets;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final heroText = Text(
      'Brands lose the account by knocking on the wrong door.',
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        fontSize: width > 1100 ? 48 : 38,
        height: 1.05,
        letterSpacing: -0.7,
        color: palette.ink,
      ),
    );
    // The hero is the first time a visitor meets the product's words. The
    // one-line gloss stays close to the terms so a reader does not have to
    // leave the page to follow along. The glossary sheet in the chrome has
    // the full list (PLAN.md §51).
    final supporting = Text(
      'Karum turns a brand (the seed) and a city into a short list of places '
      'to visit (the door board), a walking route between them, and a short '
      'pitch for every stop. Every number carries its source; every '
      'recommendation carries a reason.',
      style: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(fontSize: 17, color: palette.mute, height: 1.55),
    );
    // A Wrap rather than a fixed row: at 320 px the two buttons do not fit
    // on one line, and a Row would overflow the page instead of wrapping.
    final actions = Wrap(
      spacing: KarumSpacing.md,
      runSpacing: KarumSpacing.sm,
      children: [
        FocusRing(
          borderRadius: BorderRadius.circular(KarumRadius.control),
          child: FilledButton.icon(
            onPressed: onTryNow,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Try now'),
          ),
        ),
        FocusRing(
          borderRadius: BorderRadius.circular(KarumRadius.control),
          child: TextButton.icon(
            onPressed: onNewScout,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New scout'),
          ),
        ),
      ],
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heroText,
        const SizedBox(height: KarumSpacing.lg),
        supporting,
        const SizedBox(height: KarumSpacing.xl),
        actions,
      ],
    );

    return Container(
      padding: EdgeInsets.only(top: compact ? 4 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(KarumRadius.pill),
              border: Border.all(color: palette.brand.withValues(alpha: 0.22)),
            ),
            child: Text(
              'THE BRAND-OPERATED EXPANSION AGENT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palette.brand,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: KarumSpacing.xl),
          if (compact) ...[
            copy,
            const SizedBox(height: KarumSpacing.xl),
            const _HeroPreview(),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: copy),
                const SizedBox(width: 32),
                const Expanded(flex: 5, child: _HeroPreview()),
              ],
            ),
          const SizedBox(height: KarumSpacing.xl),
          Container(height: 1, color: palette.line),
          const SizedBox(height: KarumSpacing.lg),
          Wrap(
            spacing: KarumSpacing.xl,
            runSpacing: KarumSpacing.sm,
            children: [
              for (final city in _presetCities)
                _Proof(label: 'Yes, $city', detail: _proofDetail(city)),
              _modeProof(context),
            ],
          ),
        ],
      ),
    );
  }

  /// The mode tile in the landing proof strip, computed in its own shallow
  /// scope so the analyzer (and a reader) can see where the health snapshot
  /// comes from.
  _Proof _modeProof(BuildContext context) {
    final health = AppScope.maybeOf(context)?.health;
    return _Proof(
      label: health == null ? 'Mode —' : 'Mode ${health.mode.name}',
      detail: health == null ? 'waiting for /health' : 'the gateway says so',
    );
  }

  /// The cities the locked catalogue can run, in server order, deduplicated.
  /// Empty while the catalogue is still loading.
  List<String> get _presetCities {
    final out = <String>{};
    for (final preset in presets?.all ?? const <KarumPreset>[]) {
      out.add(preset.city.split(',').first.trim());
    }
    return out.toList()..sort();
  }

  /// The one-line proof a city's preset carries, drawn from the catalogue.
  String _proofDetail(String city) {
    switch (city) {
      case 'Austin':
        return 'Preset · bars';
      case 'Brooklyn':
        return 'Flagship + collab';
      case 'Colaba':
        return 'Preset · cafés';
      default:
        return 'Preset';
    }
  }
}

/// A still of a real run, not a live call: the names are the verified top of
/// the Austin preset's door board, and the card is labelled as a recording so
/// the landing page never implies the numbers behind it are live.
class _HeroPreview extends StatelessWidget {
  const _HeroPreview();

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(KarumRadius.card),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PREVIOUS SEARCH',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: palette.brand,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: KarumSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.paper,
                  borderRadius: BorderRadius.circular(KarumRadius.pill),
                  border: Border.all(color: palette.line),
                ),
                child: Text(
                  'RUN 01',
                  style: text.labelSmall?.copyWith(
                    color: palette.mute,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Sola in Austin',
            style: text.titleLarge?.copyWith(fontSize: 22, color: palette.ink),
          ),
          const SizedBox(height: 2),
          Text(
            'Yuzu-mezcal aperitif · Austin, TX',
            style: text.bodySmall?.copyWith(color: palette.mute),
          ),
          const SizedBox(height: KarumSpacing.lg),
          Container(height: 1, color: palette.line),
          const _HeroDoor(rank: '01', name: 'Mezcalería Tobalá'),
          Container(height: 1, color: palette.line),
          const _HeroDoor(rank: '02', name: 'Midnight Cowboy'),
          Container(height: 1, color: palette.line),
          const _HeroDoor(rank: '03', name: "Clark's Oyster Bar"),
          Container(height: 1, color: palette.line),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 14, color: palette.brand),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Every door keeps its receipts.',
                  style: text.bodySmall?.copyWith(color: palette.mute),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroDoor extends StatelessWidget {
  const _HeroDoor({required this.rank, required this.name});

  final String rank;
  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              rank,
              style: text.labelSmall?.copyWith(
                color: palette.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyLarge?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: KarumSpacing.sm),
          Icon(Icons.north_east_rounded, size: 14, color: palette.mute),
        ],
      ),
    );
  }
}

class _Proof extends StatelessWidget {
  const _Proof({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 16,
          color: palette.brand,
        ),
        const SizedBox(width: 6),
        // The two texts share the line at desktop widths and wrap onto it at
        // phone widths, so a long proof never overflows the page.
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: palette.ink),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: palette.mute),
          ),
        ),
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.index,
    required this.group,
    required this.disabled,
    required this.onRun,
    required this.onInspect,
    this.equalizeHeight = false,
  });

  final int index;
  final PresetGroup group;
  final bool disabled;
  final ValueChanged<KarumPreset> onRun;
  final ValueChanged<KarumPreset> onInspect;

  /// True in the side-by-side desktop grid, where an enclosing
  /// `IntrinsicHeight` gives every card the tallest one's height and this
  /// card needs a `Spacer` to push its button block to that shared bottom
  /// edge. False in the single-column narrow layout, where the cards stack
  /// vertically and each should keep its own natural height — a `Spacer`
  /// there has no bounded height to expand into and crashes the layout.
  final bool equalizeHeight;

  /// The button used to read "Try Sample: Sola Yuzu Mezcal in Austin, TX" —
  /// repeating the brand and city the card's own title and subtitle already
  /// show. Strips the server's "Try: " prefix so just the distinguishing
  /// detail (the part after it) moves into the card body, and the button
  /// itself can shrink to "Run again" (PLAN.md §56).
  static String _runDetail(KarumPreset preset) {
    final label = preset.buttonLabel;
    final sep = label.indexOf(': ');
    return sep == -1 ? label : label.substring(sep + 2);
  }

  Widget _runRow(
    BuildContext context,
    KarumPreset preset, {
    required bool filled,
  }) {
    final palette = KarumPalette.of(context);
    final button = FocusRing(
      borderRadius: BorderRadius.circular(KarumRadius.control),
      child: filled
          ? FilledButton(
              onPressed: disabled ? null : () => onRun(preset),
              child: const Text('Run again'),
            )
          : OutlinedButton(
              onPressed: disabled ? null : () => onRun(preset),
              child: const Text('Run again'),
            ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _runDetail(preset),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: palette.mute),
        ),
        const SizedBox(height: KarumSpacing.xs),
        button,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.xl2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // MainAxisSize.max only makes sense when an ancestor (the desktop
          // row's IntrinsicHeight) actually gives this column a bounded
          // height to fill.
          mainAxisSize: equalizeHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'PREVIOUS RUN ${(index + 1).toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.brand,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                // Moved up from the card's bottom action: it still hands the
                // free-entry builder this run's stored seed, city, and tags
                // to edit by hand, exactly as "Inspect this seed" did.
                FocusRing(
                  borderRadius: BorderRadius.circular(KarumRadius.control),
                  child: NamedIconButton(
                    label: 'Inspect this seed',
                    onPressed: disabled
                        ? null
                        : () => onInspect(group.variants.first),
                    icon: Icons.tune_rounded,
                    iconSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KarumSpacing.md),
            Text(
              group.name,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: palette.ink),
            ),
            const SizedBox(height: KarumSpacing.xs),
            Text(
              '${group.brand} · ${group.city}',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.mute),
            ),
            const SizedBox(height: KarumSpacing.md),
            Text(
              group.description,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.mute),
            ),
            const SizedBox(height: KarumSpacing.xl),
            // Absorbs the slack IntrinsicHeight adds so every card's button
            // block lands on the same baseline regardless of how many lines
            // the description above wrapped to. Only valid when the column
            // has a bounded height to expand into (see [equalizeHeight]).
            if (equalizeHeight) const Spacer(),
            if (group.variants.length == 1)
              _runRow(context, group.variants.first, filled: true)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _runRow(context, group.variants.first, filled: true),
                  const SizedBox(height: KarumSpacing.md),
                  _runRow(context, group.variants[1], filled: false),
                  // First place the brand's two mode words appear beside
                  // each other; one line of gloss keeps a first-time
                  // visitor from having to open the glossary (PLAN.md §51).
                  const Padding(
                    padding: EdgeInsets.only(top: KarumSpacing.xs),
                    child: Text(
                      'Flagship: a large own-brand store on a fitting '
                      'street. Collab: a joint event with a partner brand.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
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

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({
    required this.message,
    required this.candidates,
    required this.onCandidate,
  });

  final String message;
  final List<CityCandidate> candidates;
  final ValueChanged<CityCandidate>? onCandidate;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KarumSpacing.lg),
      decoration: BoxDecoration(
        color: palette.avoid.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KarumRadius.control),
        border: Border.all(color: palette.avoid.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: palette.avoid),
              const SizedBox(width: KarumSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: palette.ink),
                ),
              ),
            ],
          ),
          if (candidates.isNotEmpty) ...[
            const SizedBox(height: KarumSpacing.md),
            Text(
              'Choose a point:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: KarumSpacing.xs),
            for (final candidate in candidates)
              TextButton.icon(
                onPressed: onCandidate == null
                    ? null
                    : () => onCandidate!(candidate),
                icon: const Icon(Icons.place_outlined, size: 16),
                label: Text(
                  candidate.formattedAddress.isEmpty
                      ? '${candidate.point.lat}, ${candidate.point.lng}'
                      : candidate.formattedAddress,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onStatus});

  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      padding: const EdgeInsets.only(top: KarumSpacing.xl),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: Wrap(
        spacing: KarumSpacing.lg,
        runSpacing: KarumSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Karum · the right doors, not the wrong ones.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: palette.mute),
          ),
          Text(
            'Qloo associations · Google Places facts · Routes drive times',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: palette.mute),
          ),
          TextButton(
            onPressed: onStatus,
            child: const Text('Operational status'),
          ),
        ],
      ),
    );
  }
}
