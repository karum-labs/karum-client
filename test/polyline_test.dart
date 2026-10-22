import 'package:flutter_test/flutter_test.dart';
import 'package:karum/src/util/polyline.dart';

void main() {
  test('decodes the canonical Google polyline', () {
    final points = decodePolyline(r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');

    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 0.00001));
    expect(points[0].longitude, closeTo(-120.2, 0.00001));
    expect(points[1].latitude, closeTo(40.7, 0.00001));
    expect(points[1].longitude, closeTo(-120.95, 0.00001));
    expect(points[2].latitude, closeTo(43.252, 0.00001));
    expect(points[2].longitude, closeTo(-126.453, 0.00001));
  });

  test('drops coordinates that are not a real lat/lng', () {
    expect(decodePolyline(''), isEmpty);
    final points = decodePolyline('~' * 12);
    expect(
      points.where(
        (point) => point.latitude.abs() > 90 || point.longitude.abs() > 180,
      ),
      isEmpty,
    );
  });
}
