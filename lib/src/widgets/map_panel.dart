import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/scout_models.dart';
import '../config/app_config.dart';
import '../maps/google_door_map.dart';
import '../theme/brand_tokens.dart';
import '../util/polyline.dart';
import 'common.dart';

/// The map/list surface for a campaign.
///
/// The map draws only facts present in the payload: Places door coordinates
/// (falling back to the recorded Qloo place point), recorded Qloo skip points,
/// Qloo heatmap cells and locality boundaries when the flagship service
/// returned them, and Routes geometry when the server encoded it. If any of
/// those are missing, the panel says so and falls back to the ordered list
/// rather than inventing geometry.
class MapPanel extends StatefulWidget {
  const MapPanel({
    super.key,
    required this.campaign,
    this.onOpenPitch,
    this.selectedDoorId,
    this.onSelectDoor,
  });

  final Campaign campaign;
  final ValueChanged<Door>? onOpenPitch;
  final String? selectedDoorId;
  final ValueChanged<String?>? onSelectDoor;

  @override
  State<MapPanel> createState() => _MapPanelState();
}

enum _MapView { map, list }

class _MapPanelState extends State<MapPanel> {
  _MapView _view = _MapView.map;

  Door? get _selectedDoor {
    final id = widget.selectedDoorId;
    if (id == null) return null;
    for (final door in widget.campaign.doors) {
      if (door.id == id) return door;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final campaign = widget.campaign;
    final doorsWithPoints = campaign.doors
        .where((door) => door.point != null)
        .toList();
    final skipsWithPoints = campaign.skipList
        .where((skip) => skip.point != null)
        .toList();
    final cells =
        campaign.heatmap?.cells.where((cell) => cell.point.isValid).toList() ??
        const <HeatmapCell>[];
    final localityCenters =
        campaign.heatmap?.localities
            .where((locality) => locality.centroid != null)
            .toList() ??
        const <LocalityPolygon>[];
    final center =
        campaign.point ??
        (doorsWithPoints.isNotEmpty ? doorsWithPoints.first.point : null) ??
        (skipsWithPoints.isNotEmpty ? skipsWithPoints.first.point : null) ??
        (cells.isNotEmpty ? cells.first.point : null) ??
        (localityCenters.isNotEmpty ? localityCenters.first.centroid : null);
    return Container(
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, doorsWithPoints.length, skipsWithPoints.length),
          Divider(height: 1, color: palette.line),
          Expanded(
            child: _view == _MapView.list || center == null
                ? _DoorList(
                    campaign: campaign,
                    onOpenPitch: widget.onOpenPitch,
                    reason: center == null
                        ? 'The campaign arrived without a map point. '
                              'Doors remain in server order.'
                        : null,
                  )
                : _buildMap(
                    context,
                    campaign,
                    center,
                    doorsWithPoints,
                    skipsWithPoints,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, int mappedCount, int mappedSkips) {
    final palette = KarumPalette.of(context);
    final campaign = widget.campaign;
    final route = campaign.route;
    final heatmap = campaign.heatmap;
    final unmappedSkips = campaign.skipList.length - mappedSkips;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KarumSpacing.xl,
        KarumSpacing.xl,
        KarumSpacing.lg,
        KarumSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Door map'),
                    const SizedBox(height: KarumSpacing.xs),
                    Text(
                      '${campaign.doors.length} doors · $mappedCount mapped'
                      '${campaign.skipList.isEmpty ? '' : ' · ${campaign.skipList.length} skipped · $mappedSkips mapped'}',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: palette.ink),
                    ),
                  ],
                ),
              ),
              _ViewToggle(
                value: _view,
                onChanged: (view) => setState(() => _view = view),
              ),
            ],
          ),
          const SizedBox(height: KarumSpacing.sm),
          Wrap(
            spacing: KarumSpacing.sm,
            runSpacing: KarumSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (route != null && !route.skipped && !route.failed)
                _MapFact(
                  icon: Icons.route_rounded,
                  label: _routeSummary(route),
                ),
              if (route != null && route.skipped)
                _MapFact(
                  icon: Icons.route_outlined,
                  label:
                      'Route skipped${route.skipReason.isEmpty ? '' : ': ${_humanize(route.skipReason)}'}',
                  tone: palette.investigate,
                ),
              if (route != null && route.failed)
                _MapFact(
                  icon: Icons.wrong_location_outlined,
                  label: 'Route unavailable',
                  tone: palette.avoid,
                ),
              if (heatmap != null && heatmap.available)
                _MapFact(
                  icon: Icons.grain_rounded,
                  label:
                      'Heatmap · ${heatmap.cellCount} cells · '
                      '${heatmap.localities.isNotEmpty ? heatmap.localities.length : heatmap.localityCount} localities',
                  tone: palette.brand,
                ),
              if (campaign.skipList.isNotEmpty)
                _MapFact(
                  icon: Icons.remove_circle_outline,
                  label:
                      'Skip list · ${campaign.skipList.length} doors'
                      '${mappedSkips == 0 ? '' : ' · $mappedSkips mapped'}'
                      '${unmappedSkips == 0 ? '' : ' · $unmappedSkips without a point'}',
                  tone: palette.avoid,
                ),
              if (heatmap != null && !heatmap.available)
                _MapFact(
                  icon: Icons.grain_rounded,
                  label: 'Heatmap unavailable',
                  tone: palette.mute,
                ),
            ],
          ),
          if (heatmap != null && heatmap.corridors.isNotEmpty) ...[
            const SizedBox(height: KarumSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final corridor in heatmap.corridors)
                    Padding(
                      padding: const EdgeInsets.only(right: KarumSpacing.sm),
                      child: TagPill(label: corridor, selected: true),
                    ),
                ],
              ),
            ),
          ],
          if (heatmap != null &&
              !heatmap.available &&
              heatmap.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: KarumSpacing.xs),
              child: Text(
                heatmap.reason,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.mute),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    Campaign campaign,
    GeoPoint center,
    List<Door> doorsWithPoints,
    List<SkipItem> skipsWithPoints,
  ) {
    final palette = KarumPalette.of(context);
    final heatmap = campaign.heatmap;
    final route = campaign.route;
    final routePoints = _routePoints(route);
    final cells =
        heatmap?.cells.where((cell) => cell.point.isValid).toList() ??
        const <HeatmapCell>[];
    final localities =
        heatmap?.localities.where((locality) => locality.hasPolygon).toList() ??
        const <LocalityPolygon>[];
    final maxAffinity = cells.fold<double>(
      0.01,
      (max, cell) => cell.affinity > max ? cell.affinity : max,
    );
    final mapsKey = AppConfig.googleMapsWebKey;

    return Stack(
      children: [
        // The map canvas is not a keyboard surface. It draws its own focus
        // scope, and a focus that lands inside it is trapped there: Tab walks
        // the map and never reaches the board. The map carries a list of the
        // same doors in the same order, and that list is what the keyboard
        // uses — the Map/List toggle beside the map is outside this scope and
        // stays focusable, so the keyboard can still switch views.
        //
        // The scope itself must not take the focus either: a scope that can be
        // focused but holds nothing focusable is a trap of its own.
        FocusScope(
          canRequestFocus: false,
          descendantsAreFocusable: false,
          child: Semantics(
            label: 'Door map. The same doors are listed below the map.',
            child: mapsKey.isEmpty
                ? FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(center.lat, center.lng),
                      initialZoom: campaign.mode == ScoutMode.flagship
                          ? 12.2
                          : 12.8,
                      minZoom: 3,
                      maxZoom: 18,
                      backgroundColor: palette.paper,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        // The public OSM tile server refuses the burst of requests a
                        // zoom makes, and the browser reports that as "Failed to
                        // fetch", so the new zoom stays blank. CARTO serves the same
                        // OpenStreetMap data and is built for browser apps.
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        retinaMode: true,
                        userAgentPackageName: 'com.karum.app',
                        maxNativeZoom: 20,
                      ),
                      if (localities.isNotEmpty)
                        PolygonLayer(
                          polygons: [
                            for (final locality in localities)
                              Polygon(
                                points: [
                                  for (final vertex in locality.polygon)
                                    LatLng(vertex.lat, vertex.lng),
                                ],
                                color: palette.brand.withValues(alpha: 0.05),
                                borderColor: palette.brand.withValues(
                                  alpha: 0.42,
                                ),
                                borderStrokeWidth: 1.2,
                                label: locality.name,
                                labelStyle: TextStyle(
                                  color: palette.brand,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(center.lat, center.lng),
                            radius: campaign.radiusMeters.toDouble(),
                            useRadiusInMeter: true,
                            color: palette.brand.withValues(alpha: 0.05),
                            borderColor: palette.brand.withValues(alpha: 0.28),
                            borderStrokeWidth: 1,
                          ),
                          for (final cell in cells.take(300))
                            CircleMarker(
                              point: LatLng(cell.point.lat, cell.point.lng),
                              radius: 12 + (cell.affinity / maxAffinity) * 20,
                              color: palette.brand.withValues(
                                alpha:
                                    0.08 + (cell.affinity / maxAffinity) * 0.26,
                              ),
                              borderColor: palette.brand.withValues(
                                alpha: 0.28,
                              ),
                              borderStrokeWidth: 0.8,
                            ),
                        ],
                      ),
                      if (routePoints.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routePoints,
                              strokeWidth: 4,
                              color: palette.brand,
                              borderStrokeWidth: 1.5,
                              borderColor: palette.surface,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          for (final skip in skipsWithPoints)
                            Marker(
                              point: LatLng(skip.point!.lat, skip.point!.lng),
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              child: Semantics(
                                container: true,
                                label:
                                    'Skipped door ${skip.name}: ${skip.reasonLabel}',
                                child: Tooltip(
                                  message: '${skip.name} · ${skip.reasonLabel}',
                                  excludeFromSemantics: true,
                                  child: const _SkipPin(),
                                ),
                              ),
                            ),
                          for (final door in doorsWithPoints)
                            Marker(
                              point: LatLng(door.point!.lat, door.point!.lng),
                              width: widget.selectedDoorId == door.id ? 44 : 34,
                              height: widget.selectedDoorId == door.id
                                  ? 44
                                  : 34,
                              alignment: Alignment.center,
                              child: Semantics(
                                container: true,
                                button: true,
                                excludeSemantics: true,
                                label:
                                    'Recommended door ${door.rank}: ${door.name}',
                                onTap: () => widget.onSelectDoor?.call(door.id),
                                child: Tooltip(
                                  message: '${door.rank}. ${door.name}',
                                  excludeFromSemantics: true,
                                  child: InkWell(
                                    onTap: () =>
                                        widget.onSelectDoor?.call(door.id),
                                    customBorder: const CircleBorder(),
                                    excludeFromSemantics: true,
                                    child: _DoorPin(
                                      rank: door.rank,
                                      selected:
                                          widget.selectedDoorId == door.id,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  )
                : GoogleDoorMap(
                    apiKey: mapsKey,
                    center: center,
                    zoom: campaign.mode == ScoutMode.flagship ? 12.2 : 12.8,
                    radiusMeters: campaign.radiusMeters,
                    brand: palette.brand,
                    doors: doorsWithPoints,
                    skips: skipsWithPoints,
                    cells: cells,
                    localities: localities,
                    routePoints: routePoints,
                    selectedDoorId: widget.selectedDoorId,
                    onSelectDoor: widget.onSelectDoor,
                  ),
          ),
        ),
        Positioned(
          left: KarumSpacing.md,
          top: KarumSpacing.md,
          child: _Legend(
            hasHeatmap: cells.isNotEmpty,
            hasLocalities: localities.isNotEmpty,
            hasRoute: routePoints.length > 1,
            hasSkips: skipsWithPoints.isNotEmpty,
          ),
        ),
        if (_selectedDoor != null)
          Positioned(
            left: KarumSpacing.md,
            right: KarumSpacing.md,
            bottom: KarumSpacing.lg,
            child: _SelectedDoorCard(
              door: _selectedDoor!,
              onOpen: widget.onOpenPitch == null
                  ? null
                  : () => widget.onOpenPitch!(_selectedDoor!),
              onClose: () => widget.onSelectDoor?.call(null),
            ),
          ),
        Positioned(
          right: KarumSpacing.md,
          bottom: KarumSpacing.md,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.line),
            ),
            child: Text(
              mapsKey.isNotEmpty
                  ? 'Map data © Google'
                  : _hasGoogleFacts(campaign)
                  ? '© OpenStreetMap © CARTO · Map data © Google'
                  : '© OpenStreetMap © CARTO',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.mute, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }

  List<LatLng> _routePoints(RoutePlan? route) {
    if (route == null) return const [];
    if (route.polyline.isNotEmpty) return decodePolyline(route.polyline);
    final points = <LatLng>[];
    for (final leg in route.legs) {
      points.addAll(decodePolyline(leg.polyline));
    }
    return points;
  }

  String _routeSummary(RoutePlan route) {
    final meters = route.legs.fold<int>(
      0,
      (sum, leg) => sum + leg.distanceMeters,
    );
    final stops = route.stopIds.isEmpty
        ? widget.campaign.doors.length
        : route.stopIds.length;
    if (meters == 0) return '$stops stops · route ready';
    final km = (meters / 1000).toStringAsFixed(1);
    return '$stops stops · $km km';
  }

  bool _hasGoogleFacts(Campaign campaign) =>
      campaign.route != null ||
      campaign.doors.any((door) => door.enrichment != null);
}

class _DoorList extends StatelessWidget {
  const _DoorList({
    required this.campaign,
    required this.onOpenPitch,
    this.reason,
  });

  final Campaign campaign;
  final ValueChanged<Door>? onOpenPitch;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Column(
      children: [
        if (reason != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KarumSpacing.md),
            color: palette.investigate.withValues(alpha: 0.1),
            child: Text(
              reason!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.ink),
            ),
          ),
        Expanded(
          child: campaign.doors.isEmpty
              ? const PanePlaceholder(
                  icon: Icons.location_off_outlined,
                  title: 'No mapped doors',
                  message: 'The board is empty or no door has Places geometry.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(KarumSpacing.lg),
                  itemCount: campaign.doors.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: KarumSpacing.sm),
                  itemBuilder: (context, index) {
                    final door = campaign.doors[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onOpenPitch == null
                            ? null
                            : () => onOpenPitch!(door),
                        borderRadius: BorderRadius.circular(
                          KarumRadius.control,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(KarumSpacing.md),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              KarumRadius.control,
                            ),
                            border: Border.all(color: palette.line),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _RankBadge(rank: door.rank),
                              const SizedBox(width: KarumSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      door.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(color: palette.ink),
                                    ),
                                    if (door.enrichment != null &&
                                        door
                                            .enrichment!
                                            .address
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        door.enrichment!.address,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: palette.mute),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      door.enrichment?.openLabel ??
                                          'Places unknown',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: palette.mute),
                                    ),
                                  ],
                                ),
                              ),
                              if (index == 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.brand.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      KarumRadius.pill,
                                    ),
                                  ),
                                  child: Text(
                                    'First stop',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: palette.brand),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});

  final _MapView value;
  final ValueChanged<_MapView> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(KarumRadius.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggle(
            context,
            icon: Icons.map_outlined,
            label: 'Map',
            selected: value == _MapView.map,
            onTap: () => onChanged(_MapView.map),
          ),
          _toggle(
            context,
            icon: Icons.list_alt_rounded,
            label: 'List',
            selected: value == _MapView.list,
            onTap: () => onChanged(_MapView.list),
          ),
        ],
      ),
    );
  }

  Widget _toggle(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final palette = KarumPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label view',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KarumRadius.control - 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? palette.brand.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(KarumRadius.control - 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? palette.brand : palette.mute,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? palette.brand : palette.mute,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoorPin extends StatelessWidget {
  const _DoorPin({
    required this.rank,
    required this.selected,
    this.size,
    this.fontSize,
  });

  final int rank;
  final bool selected;
  final double? size;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? palette.brand : palette.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? palette.surface : palette.brand,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.ink.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: selected ? palette.onBrand : palette.brand,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

class _SkipPin extends StatelessWidget {
  const _SkipPin({this.size, this.iconSize});

  final double? size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: palette.avoid, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.remove, size: iconSize ?? 18, color: palette.avoid),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.brand.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: palette.brand.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$rank',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: palette.brand, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MapFact extends StatelessWidget {
  const _MapFact({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final color = tone ?? palette.mute;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.hasHeatmap,
    required this.hasLocalities,
    required this.hasRoute,
    required this.hasSkips,
  });

  final bool hasHeatmap;
  final bool hasLocalities;
  final bool hasRoute;
  final bool hasSkips;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(KarumRadius.control),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendRow(
            palette.brand,
            'Recommended door',
            palette,
            symbol: const SizedBox(
              key: Key('legend-door-pin'),
              width: 16,
              height: 16,
              child: _DoorPin(rank: 1, selected: false, size: 16, fontSize: 9),
            ),
          ),
          if (hasSkips) ...[
            const SizedBox(height: 4),
            _legendRow(
              palette.avoid,
              'Skipped door',
              palette,
              symbol: const SizedBox(
                key: Key('legend-skip-pin'),
                width: 16,
                height: 16,
                child: _SkipPin(size: 16, iconSize: 9),
              ),
            ),
          ],
          if (hasLocalities) ...[
            const SizedBox(height: 4),
            _legendRow(
              palette.brand.withValues(alpha: 0.2),
              'Qloo locality',
              palette,
            ),
          ],
          if (hasRoute) ...[
            const SizedBox(height: 4),
            _legendRow(palette.brand, 'Field route', palette, line: true),
          ],
          if (hasHeatmap) ...[
            const SizedBox(height: 4),
            _legendRow(
              palette.brand.withValues(alpha: 0.35),
              'Qloo density cell',
              palette,
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendRow(
    Color color,
    String label,
    KarumPalette palette, {
    bool line = false,
    Widget? symbol,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: Center(
            child:
                symbol ??
                Container(
                  width: line ? 14 : 8,
                  height: line ? 3 : 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(line ? 2 : 99),
                  ),
                ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: KarumFonts.body,
            fontSize: 10,
            color: palette.mute,
          ),
        ),
      ],
    );
  }
}

class _SelectedDoorCard extends StatelessWidget {
  const _SelectedDoorCard({
    required this.door,
    required this.onOpen,
    required this.onClose,
  });

  final Door door;
  final VoidCallback? onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Card(
      color: palette.surface,
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.md),
        child: Row(
          children: [
            _RankBadge(rank: door.rank),
            const SizedBox(width: KarumSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    door.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    door.enrichment?.address ?? 'Places unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: palette.mute),
                  ),
                ],
              ),
            ),
            if (onOpen != null)
              FilledButton(onPressed: onOpen, child: const Text('Pitch')),
            NamedIconButton(
              label: 'Close door preview',
              onPressed: onClose,
              icon: Icons.close_rounded,
              iconSize: 18,
            ),
          ],
        ),
      ),
    );
  }
}

String _humanize(String value) {
  final cleaned = value.replaceAll('_', ' ').trim();
  if (cleaned.isEmpty) return value;
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}
