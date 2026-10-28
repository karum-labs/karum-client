import 'dart:async';

import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../api/scout_models.dart';
import '../theme/brand_tokens.dart';
import 'google_maps_script.dart';
import 'google_marker_icons.dart';
import 'place_detail.dart';

/// Google Maps canvas for one campaign.
///
/// The street picture comes from the Maps JavaScript API. Pins, the scout
/// radius, heatmap cells, locality outlines, and the driving line are the
/// same facts the OpenStreetMap canvas draws.
class GoogleDoorMap extends StatefulWidget {
  const GoogleDoorMap({
    super.key,
    required this.apiKey,
    required this.center,
    required this.zoom,
    required this.radiusMeters,
    required this.brand,
    required this.doors,
    required this.skips,
    required this.cells,
    required this.localities,
    required this.routePoints,
    required this.selectedDoorId,
    required this.onSelectDoor,
  });

  final String apiKey;
  final GeoPoint center;
  final double zoom;
  final int radiusMeters;
  final Color brand;
  final List<Door> doors;
  final List<SkipItem> skips;
  final List<HeatmapCell> cells;
  final List<LocalityPolygon> localities;
  final List<ll.LatLng> routePoints;
  final String? selectedDoorId;
  final ValueChanged<String?>? onSelectDoor;

  @override
  State<GoogleDoorMap> createState() => _GoogleDoorMapState();
}

class _GoogleDoorMapState extends State<GoogleDoorMap> {
  var _ready = false;
  Object? _error;

  KarumPalette? _palette;
  GoogleMarkerIcons? _markerIcons;
  Map<String, BitmapDescriptor> _icons = const {};
  var _iconsReady = false;
  var _iconGeneration = 0;

  @override
  void initState() {
    super.initState();
    ensureGoogleMapsLoaded(widget.apiKey)
        .then((_) {
          if (mounted) setState(() => _ready = true);
        })
        .catchError((Object error) {
          if (mounted) setState(() => _error = error);
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final palette = KarumPalette.of(context);
    if (identical(_palette, palette)) return;
    _palette = palette;
    _markerIcons = GoogleMarkerIcons(palette);
    _icons = const {};
    _iconsReady = false;
    unawaited(_loadIcons());
  }

  @override
  void didUpdateWidget(covariant GoogleDoorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doors != widget.doors ||
        oldWidget.skips != widget.skips ||
        oldWidget.selectedDoorId != widget.selectedDoorId) {
      unawaited(_loadIcons());
    }
  }

  Future<void> _loadIcons() async {
    final generator = _markerIcons;
    if (generator == null) return;
    final generation = ++_iconGeneration;
    final next = <String, BitmapDescriptor>{};
    try {
      if (widget.skips.isNotEmpty) {
        next[GoogleMarkerIcons.skipKey(selected: false)] = await generator
            .skip();
      }
      for (final door in widget.doors) {
        if (door.point == null) continue;
        final selected = widget.selectedDoorId == door.id;
        next[GoogleMarkerIcons.doorKey(door.rank, selected: selected)] =
            await generator.door(door.rank, selected: selected);
      }
    } catch (_) {
      if (!mounted || generation != _iconGeneration) return;
      setState(() => _iconsReady = true);
      return;
    }
    if (!mounted || generation != _iconGeneration) return;
    setState(() {
      _icons = next;
      _iconsReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Google Maps did not load. The door list is still available.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!_ready || !_iconsReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final maxAffinity = widget.cells.fold<double>(
      0.01,
      (max, cell) => cell.affinity > max ? cell.affinity : max,
    );
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.center.lat, widget.center.lng),
        zoom: widget.zoom,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(3, 18),
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      circles: {
        Circle(
          circleId: const CircleId('scout-radius'),
          center: LatLng(widget.center.lat, widget.center.lng),
          radius: widget.radiusMeters.toDouble(),
          fillColor: widget.brand.withValues(alpha: 0.05),
          strokeColor: widget.brand.withValues(alpha: 0.28),
          strokeWidth: 1,
        ),
        for (var i = 0; i < widget.cells.length && i < 300; i++)
          Circle(
            circleId: CircleId('heat-$i'),
            center: LatLng(
              widget.cells[i].point.lat,
              widget.cells[i].point.lng,
            ),
            radius: 90 + (widget.cells[i].affinity / maxAffinity) * 220,
            fillColor: widget.brand.withValues(
              alpha: 0.12 + (widget.cells[i].affinity / maxAffinity) * 0.28,
            ),
            strokeColor: widget.brand.withValues(alpha: 0.35),
            strokeWidth: 1,
          ),
      },
      polygons: {
        for (final locality in widget.localities)
          Polygon(
            polygonId: PolygonId(locality.name),
            points: [
              for (final vertex in locality.polygon)
                LatLng(vertex.lat, vertex.lng),
            ],
            fillColor: widget.brand.withValues(alpha: 0.08),
            strokeColor: widget.brand.withValues(alpha: 0.7),
            strokeWidth: 2,
          ),
      },
      polylines: {
        if (widget.routePoints.length > 1)
          Polyline(
            polylineId: const PolylineId('route'),
            points: [
              for (final point in widget.routePoints)
                LatLng(point.latitude, point.longitude),
            ],
            color: widget.brand,
            width: 4,
          ),
      },
      markers: {
        for (var i = 0; i < widget.skips.length; i++)
          if (widget.skips[i].point != null)
            Marker(
              markerId: MarkerId('skip-$i-${widget.skips[i].id}'),
              position: LatLng(
                widget.skips[i].point!.lat,
                widget.skips[i].point!.lng,
              ),
              icon:
                  _icons[GoogleMarkerIcons.skipKey(selected: false)] ??
                  BitmapDescriptor.defaultMarker,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 1,
              infoWindow: InfoWindow(
                title: widget.skips[i].name,
                snippet: widget.skips[i].reasonLabel,
              ),
              onTap: () async {
                final ctx = context;
                final skip = widget.skips[i];
                final details = await fetchPlaceDetails(
                  placeName: skip.name,
                  lat: skip.point!.lat,
                  lng: skip.point!.lng,
                );
                if (!mounted || !ctx.mounted) return;
                if (details.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('No place details found')),
                  );
                  return;
                }
                showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => PlaceDetailBottomSheet(details: details),
                );
              },
            ),
        for (final door in widget.doors)
          if (door.point != null)
            Marker(
              markerId: MarkerId(door.id),
              position: LatLng(door.point!.lat, door.point!.lng),
              icon:
                  _icons[GoogleMarkerIcons.doorKey(
                    door.rank,
                    selected: widget.selectedDoorId == door.id,
                  )] ??
                  BitmapDescriptor.defaultMarker,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: widget.selectedDoorId == door.id ? 3 : 2,
              infoWindow: InfoWindow(title: '${door.rank}. ${door.name}'),
              onTap: () async {
                final ctx = context;
                widget.onSelectDoor?.call(door.id);
                final details = await fetchPlaceDetails(
                  placeName: door.name,
                  lat: door.point!.lat,
                  lng: door.point!.lng,
                );
                if (!mounted || !ctx.mounted) return;
                if (details.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('No place details found')),
                  );
                  return;
                }
                showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => PlaceDetailBottomSheet(details: details),
                );
              },
            ),
      },
    );
  }
}
