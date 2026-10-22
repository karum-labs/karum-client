import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../api/scout_models.dart';
import 'google_maps_script.dart';

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
  final ValueChanged<String> onSelectDoor;

  @override
  State<GoogleDoorMap> createState() => _GoogleDoorMapState();
}

class _GoogleDoorMapState extends State<GoogleDoorMap> {
  var _ready = false;
  Object? _error;

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
    if (!_ready) {
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
        for (final skip in widget.skips)
          if (skip.point != null)
            Marker(
              markerId: MarkerId('skip-${skip.id}'),
              position: LatLng(skip.point!.lat, skip.point!.lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              infoWindow: InfoWindow(
                title: skip.name,
                snippet: skip.reasonLabel,
              ),
            ),
        for (final door in widget.doors)
          if (door.point != null)
            Marker(
              markerId: MarkerId(door.id),
              position: LatLng(door.point!.lat, door.point!.lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                widget.selectedDoorId == door.id
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(title: '${door.rank}. ${door.name}'),
              onTap: () => widget.onSelectDoor(door.id),
            ),
      },
    );
  }
}
