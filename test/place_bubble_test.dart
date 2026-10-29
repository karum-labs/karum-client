import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karum/src/maps/place_bubble.dart';
import 'package:karum/src/maps/place_detail.dart';
import 'package:karum/src/theme/app_theme.dart';

// PLAN.md §63: one bubble per pin, Karum's facts at once and the Places
// lookup filling in behind them.

const _hours = [
  'Monday: 4 PM – 2 AM',
  'Tuesday: 5 PM – 2 AM',
  'Wednesday: 4 PM – 2 AM',
  'Thursday: 4 PM – 2 AM',
  'Friday: 4 PM – 3 AM',
  'Saturday: 4 PM – 3 AM',
  'Sunday: Closed',
];

PlaceDetails _full() => PlaceDetails(
  name: "Whisler's",
  address: '1816 E 6th St, Austin, TX',
  phone: '+1 512-480-0781',
  website: 'https://www.whislers.com/menu',
  mapsUrl: 'https://maps.google.com/?cid=1',
  rating: 4.5,
  ratingCount: 1234,
  priceLevel: 2,
  category: 'Cocktail bar',
  summary: 'Mezcal-forward bar with a garden.',
  openNow: true,
  utcOffsetMinutes: -300,
  openingHours: _hours,
  reviews: const [
    PlaceReview(
      author: 'Ana',
      text: 'Great mezcal list.',
      rating: 5,
      relativeTime: '3 weeks ago',
    ),
    PlaceReview(author: 'Ben', text: 'Loud but fun.', rating: 4),
    PlaceReview(author: 'Cy', text: 'Third review text.', rating: 3),
  ],
);

const _doorFacts = PlaceBubbleFacts.door(
  title: "Whisler's",
  rank: 3,
  score: 72.4,
  sharedTags: ['Bars', 'Cocktails'],
);

Future<void> _show(
  WidgetTester tester, {
  required PlaceBubbleFacts facts,
  required Future<PlaceDetails?> details,
  VoidCallback? onClose,
  PlaceDetailsRepository? repository,
}) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 340,
            child: PlaceBubbleCard(
              facts: facts,
              details: details,
              onClose: onClose ?? () {},
              repository: repository,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('the card', () {
    testWidgets('shows Karum facts at once, before the lookup answers', (
      tester,
    ) async {
      final pending = Completer<PlaceDetails?>();
      await _show(tester, facts: _doorFacts, details: pending.future);
      await tester.pump();

      expect(find.text("Whisler's"), findsOneWidget);
      expect(find.text('Karum score 72 · door 3'), findsOneWidget);
      expect(find.text('Shares: Bars, Cocktails'), findsOneWidget);
      // The lookup is out: a skeleton, not an error, and no sheet.
      expect(find.bySemanticsLabel('Loading place details'), findsOneWidget);
      expect(find.text('Place details unavailable'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('fills in the Places block when the lookup lands', (
      tester,
    ) async {
      await _show(tester, facts: _doorFacts, details: Future.value(_full()));
      await tester.pumpAndSettle();

      expect(find.text('Google fact'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('(1,234)'), findsOneWidget);
      expect(find.text(r'$$'), findsOneWidget);
      expect(find.text('Cocktail bar'), findsOneWidget);
      expect(find.text('Open now'), findsOneWidget);
      expect(find.text('1816 E 6th St, Austin, TX'), findsOneWidget);
      expect(find.text('+1 512-480-0781'), findsOneWidget);
      // The website shows as a host, not a whole URL.
      expect(find.text('whislers.com'), findsOneWidget);
      expect(find.text('Mezcal-forward bar with a garden.'), findsOneWidget);
      // Two reviews up front, with who wrote them and when.
      expect(find.text('Great mezcal list.'), findsOneWidget);
      expect(find.text('★ 5 · Ana · 3 weeks ago'), findsOneWidget);
      expect(find.text('Loud but fun.'), findsOneWidget);
      expect(find.text('Third review text.'), findsNothing);
      expect(find.text('Place details unavailable'), findsNothing);
    });

    testWidgets('More details unfolds the rest, and Fewer folds it back', (
      tester,
    ) async {
      await _show(tester, facts: _doorFacts, details: Future.value(_full()));
      await tester.pumpAndSettle();

      expect(find.text('Sunday: Closed'), findsNothing);
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();

      expect(find.text('Third review text.'), findsOneWidget);
      expect(find.text('Sunday: Closed'), findsOneWidget);
      expect(find.text('Open in Google Maps'), findsOneWidget);

      await tester.tap(find.text('Fewer details'));
      await tester.pumpAndSettle();
      expect(find.text('Third review text.'), findsNothing);
    });

    testWidgets('a failed lookup keeps the Karum facts and says so quietly', (
      tester,
    ) async {
      await _show(tester, facts: _doorFacts, details: Future.value(null));
      await tester.pumpAndSettle();

      expect(find.text('Karum score 72 · door 3'), findsOneWidget);
      expect(find.text('Place details unavailable'), findsOneWidget);
      // Not a snackbar: nothing to dismiss.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a lookup that comes back empty reads as unavailable too', (
      tester,
    ) async {
      await _show(
        tester,
        facts: _doorFacts,
        details: Future.value(const PlaceDetails(name: "Whisler's")),
      );
      await tester.pumpAndSettle();
      expect(find.text('Place details unavailable'), findsOneWidget);
    });

    testWidgets('a skipped venue shows why it was skipped', (tester) async {
      await _show(
        tester,
        facts: const PlaceBubbleFacts.skipped(
          title: "Maggie Mae's",
          reason: 'Below the shortlist floor',
          reasonDetail: '0.8160 below the returned floor 0.8386',
        ),
        details: Future.value(null),
      );
      await tester.pumpAndSettle();

      expect(find.text('Below the shortlist floor'), findsOneWidget);
      expect(
        find.text('0.8160 below the returned floor 0.8386'),
        findsOneWidget,
      );
      // A skipped venue has no pitch to open.
      expect(find.text('Open pitch & route'), findsNothing);
    });

    testWidgets('a door offers its pitch, and the button calls through', (
      tester,
    ) async {
      var opened = 0;
      await _show(
        tester,
        facts: PlaceBubbleFacts.door(
          title: "Whisler's",
          rank: 3,
          onOpenPitch: () => opened++,
        ),
        details: Future.value(null),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open pitch & route'));
      expect(opened, 1);
    });

    testWidgets('the close button and Escape both dismiss it', (tester) async {
      var closed = 0;
      await _show(
        tester,
        facts: _doorFacts,
        details: Future.value(null),
        onClose: () => closed++,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close place details'));
      expect(closed, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closed, 2);
    });

    testWidgets('the photographer is credited beside the picture', (
      tester,
    ) async {
      // A 1x1 PNG as the gateway's data URI.
      const png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'photo_data': 'data:image/png;base64,$png'}),
          200,
        ),
      );
      await _show(
        tester,
        facts: _doorFacts,
        details: Future.value(
          const PlaceDetails(
            address: '1 Main St',
            photos: [PlacePhoto(name: 'places/a/photos/b', author: 'Sam')],
          ),
        ),
        repository: PlaceDetailsRepository(client: client),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Photo: Sam · Google'), findsOneWidget);
    });
  });

  group('the venue\'s own day', () {
    test('today is read in the venue\'s time zone, not the visitor\'s', () {
      // Monday 23:00 UTC.
      final now = DateTime.utc(2026, 10, 26, 23);
      // Austin is five hours behind: still Monday.
      expect(
        PlaceDetails(
          openingHours: _hours,
          utcOffsetMinutes: -300,
        ).todaysHours(now: now),
        'Monday: 4 PM – 2 AM',
      );
      // Mumbai is five and a half hours ahead: already Tuesday.
      expect(
        PlaceDetails(
          openingHours: _hours,
          utcOffsetMinutes: 330,
        ).todaysHours(now: now),
        'Tuesday: 5 PM – 2 AM',
      );
    });

    test('no offset or an incomplete week gives no line, never a guess', () {
      expect(PlaceDetails(openingHours: _hours).todaysHours(), isNull);
      expect(
        const PlaceDetails(
          openingHours: ['Monday: 9 AM'],
          utcOffsetMinutes: 0,
        ).todaysHours(),
        isNull,
      );
    });

    testWidgets('the card shows today in the venue\'s day', (tester) async {
      // Frozen via the details themselves: an offset puts today on a line, and
      // the card prints it after the open/closed status.
      await _show(tester, facts: _doorFacts, details: Future.value(_full()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Today: '), findsOneWidget);
    });
  });

  group('placement', () {
    const map = Size(800, 600);

    test('sits above the pin when there is room', () {
      final p = placeBubble(anchor: const Offset(400, 450), map: map);
      expect(p.visible, isTrue);
      expect(p.above, isTrue);
      // The bubble's bottom edge is just over the marker.
      expect(p.edge, lessThan(450));
    });

    test('flips below when the pin is too near the top', () {
      final p = placeBubble(anchor: const Offset(400, 90), map: map);
      expect(p.above, isFalse);
      expect(p.edge, greaterThan(90));
    });

    test('stays inside the margins and still points at the pin', () {
      final nearRight = placeBubble(anchor: const Offset(790, 450), map: map);
      expect(nearRight.left + nearRight.width, lessThanOrEqualTo(800 - 64));
      // The tail is clamped to the card but leans toward the pin.
      expect(nearRight.tailX, nearRight.width - 18);

      final nearLeft = placeBubble(anchor: const Offset(5, 450), map: map);
      expect(nearLeft.left, 12);
      expect(nearLeft.tailX, 18);
    });

    test('is hidden once the pin leaves the map', () {
      expect(
        placeBubble(anchor: const Offset(-200, 300), map: map).visible,
        isFalse,
      );
      expect(
        placeBubble(anchor: const Offset(400, 900), map: map).visible,
        isFalse,
      );
    });

    test('narrows on a phone-width map', () {
      final p = placeBubble(
        anchor: const Offset(160, 400),
        map: const Size(320, 640),
      );
      expect(p.width, lessThan(340));
      expect(p.left, greaterThanOrEqualTo(12));
    });
  });

  group('the layer', () {
    Future<void> pumpLayer(WidgetTester tester, Offset? anchor) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: PlaceBubbleLayer(
                    anchor: anchor,
                    mapSize: const Size(800, 600),
                    facts: _doorFacts,
                    details: Future.value(null),
                    onClose: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('draws one card when the pin is on the map', (tester) async {
      await pumpLayer(tester, const Offset(400, 450));
      expect(find.byType(PlaceBubbleCard), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('draws nothing without an anchor or off the map', (
      tester,
    ) async {
      await pumpLayer(tester, null);
      expect(find.byType(PlaceBubbleCard), findsNothing);
      await pumpLayer(tester, const Offset(-300, 100));
      expect(find.byType(PlaceBubbleCard), findsNothing);
    });

    testWidgets('keeps the card inside the map when the pin is near the top', (
      tester,
    ) async {
      await pumpLayer(tester, const Offset(400, 90));
      final card = tester.getRect(find.byType(PlaceBubbleCard));
      expect(card.top, greaterThanOrEqualTo(0));
      expect(card.bottom, lessThanOrEqualTo(600));
      // It flipped below the pin rather than clipping off the top.
      expect(card.top, greaterThan(90));
    });
  });

  group('the lookup and its cache', () {
    // The real gateway answers UTF-8 (the hours carry an en dash); the test
    // response must say so, or http encodes the body as Latin-1 and throws.
    const utf8Json = {'content-type': 'application/json; charset=utf-8'};

    http.Response okPlace() => http.Response(
      jsonEncode({
        'status': 'OK',
        'result': {
          'name': "Whisler's",
          'formatted_address': '1816 E 6th St',
          'formatted_phone_number': '+1 512-480-0781',
          'rating': 4.5,
          'rating_count': 1234,
          'price_level': 2,
          'open_now': true,
          'utc_offset_minutes': -300,
          'opening_hours': _hours,
          'reviews': [
            {'author': 'Ana', 'text': 'Great.', 'rating': 5},
          ],
          'photos': [
            {'name': 'places/a/photos/b', 'author': 'Sam'},
          ],
        },
      }),
      200,
      headers: utf8Json,
    );

    test('parses the gateway\'s shape', () async {
      final repo = PlaceDetailsRepository(
        client: MockClient((_) async => okPlace()),
      );
      final details = await repo.load(
        name: "Whisler's",
        lat: 30.26,
        lng: -97.72,
      );
      expect(details!.address, '1816 E 6th St');
      expect(details.ratingCount, 1234);
      expect(details.priceLevel, 2);
      expect(details.openNow, isTrue);
      expect(details.reviews.single.author, 'Ana');
      expect(details.photos.single.author, 'Sam');
      expect(details.openingHours, hasLength(7));
    });

    test('sends the pin and no field list', () async {
      late Uri seen;
      final repo = PlaceDetailsRepository(
        client: MockClient((request) async {
          seen = request.url;
          return okPlace();
        }),
      );
      await repo.load(name: "Whisler's", lat: 30.26, lng: -97.72);
      expect(seen.path, endsWith('/api/v1/places/details'));
      expect(seen.queryParameters['lat'], '30.26');
      expect(seen.queryParameters['lng'], '-97.72');
      expect(seen.queryParameters['place_name'], "Whisler's");
      // The field list belongs to the gateway.
      expect(seen.queryParameters.containsKey('fields'), isFalse);
    });

    test(
      'a second tap on the same pin does not call the gateway again',
      () async {
        var calls = 0;
        final repo = PlaceDetailsRepository(
          client: MockClient((_) async {
            calls++;
            return okPlace();
          }),
        );
        final first = repo.load(name: "Whisler's", lat: 30.26, lng: -97.72);
        // Taps that land while the call is in flight share it.
        final second = repo.load(name: "Whisler's", lat: 30.26, lng: -97.72);
        await Future.wait([first, second]);
        await repo.load(name: "Whisler's", lat: 30.26, lng: -97.72);
        expect(calls, 1);

        // A different pin is its own lookup.
        await repo.load(name: "Whisler's", lat: 40.7, lng: -73.9);
        expect(calls, 2);
      },
    );

    test('a failed call is retried on the next tap, not remembered', () async {
      var calls = 0;
      final repo = PlaceDetailsRepository(
        client: MockClient((_) async {
          calls++;
          return calls == 1 ? http.Response('busy', 429) : okPlace();
        }),
      );
      expect(await repo.load(name: 'A', lat: 1, lng: 2), isNull);
      final retried = await repo.load(name: 'A', lat: 1, lng: 2);
      expect(retried, isNotNull);
      expect(calls, 2);
    });

    test(
      'a venue Google does not know is remembered, so no second billed call',
      () async {
        var calls = 0;
        final repo = PlaceDetailsRepository(
          client: MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({'status': 'NOT_FOUND', 'result': null}),
              200,
            );
          }),
        );
        expect(await repo.load(name: 'Nowhere', lat: 1, lng: 2), isNull);
        expect(await repo.load(name: 'Nowhere', lat: 1, lng: 2), isNull);
        expect(calls, 1);
      },
    );
  });
}
