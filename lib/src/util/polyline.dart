import 'package:latlong2/latlong.dart';

/// Decodes a Google encoded polyline into map points.
///
/// The gateway stores the Routes API polyline verbatim. Decoding uses
/// arithmetic instead of bitwise shifts: Flutter web compiles those shifts to
/// 32-bit JavaScript operations, which corrupt a normal driving route into
/// latitudes in the millions and crash the map.
///
/// Points outside the valid latitude and longitude ranges are dropped, so a
/// truncated or non-polyline string cannot reach the map layer.
List<LatLng> decodePolyline(String encoded) {
  if (encoded.isEmpty) return const [];
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    final latDelta = _delta(encoded, index);
    if (latDelta == null) break;
    index = latDelta.next;
    lat += latDelta.value;

    final lngDelta = _delta(encoded, index);
    if (lngDelta == null) break;
    index = lngDelta.next;
    lng += lngDelta.value;

    final latitude = lat / 1e5;
    final longitude = lng / 1e5;
    if (latitude.abs() > 90 || longitude.abs() > 180) continue;
    points.add(LatLng(latitude, longitude));
  }
  return points;
}

class _Delta {
  const _Delta(this.value, this.next);

  final int value;
  final int next;
}

/// Reads one zigzag-encoded integer and the index just past it.
_Delta? _delta(String encoded, int index) {
  if (index >= encoded.length) return null;
  var result = 0;
  var factor = 1;
  while (index < encoded.length) {
    final byte = encoded.codeUnitAt(index) - 63;
    index++;
    if (byte < 0) return null;
    result += (byte % 32) * factor;
    if (byte < 32) break;
    factor *= 32;
    // A real coordinate never needs this many chunks. Stop a runaway string.
    if (factor > 1000000000000000) return null;
  }
  final magnitude = result ~/ 2;
  final value = result.isOdd ? -magnitude - 1 : magnitude;
  return _Delta(value, index);
}
