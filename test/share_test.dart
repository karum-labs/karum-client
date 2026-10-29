import 'package:flutter_test/flutter_test.dart';
import 'package:karum/src/util/share.dart';

void main() {
  test('a shared route stays an app route, not a gateway API path', () {
    expect(appUrl('/scout/run-0041'), '/scout/run-0041');
    expect(appUrl('scout/run-0041/doors/d-1'), '/scout/run-0041/doors/d-1');
  });
}
