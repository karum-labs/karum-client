import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// One review excerpt, already trimmed by the gateway.
class PlaceReview {
  const PlaceReview({
    required this.author,
    required this.text,
    this.rating,
    this.relativeTime = '',
  });

  final String author;
  final String text;
  final double? rating;

  /// Google's own phrasing, such as "3 weeks ago".
  final String relativeTime;

  factory PlaceReview.fromJson(Map<String, dynamic> json) => PlaceReview(
    author: (json['author'] ?? '').toString(),
    text: (json['text'] ?? '').toString(),
    rating: (json['rating'] as num?)?.toDouble(),
    relativeTime: (json['relative_time'] ?? '').toString(),
  );
}

/// One photo reference. The image itself comes from [fetchPhotoUrl].
class PlacePhoto {
  const PlacePhoto({required this.name, this.author = ''});

  final String name;

  /// The photographer Google credits; shown beside the picture.
  final String author;

  factory PlacePhoto.fromJson(Map<String, dynamic> json) => PlacePhoto(
    name: (json['name'] ?? '').toString(),
    author: (json['author'] ?? '').toString(),
  );
}

/// What the gateway's `GET /api/v1/places/details` returns for one venue.
///
/// Every field here is a Google Places fact. The bubble labels the block as
/// one, and Karum's own rank, score, and skip reason come from the run payload
/// instead, so the two are never mixed under one source label.
class PlaceDetails {
  const PlaceDetails({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.website = '',
    this.mapsUrl = '',
    this.rating,
    this.ratingCount = 0,
    this.priceLevel = 0,
    this.category = '',
    this.summary = '',
    this.openNow,
    this.utcOffsetMinutes,
    this.openingHours = const [],
    this.reviews = const [],
    this.photos = const [],
  });

  final String name;
  final String address;
  final String phone;
  final String website;
  final String mapsUrl;
  final double? rating;
  final int ratingCount;

  /// 1 (inexpensive) to 4 (very expensive); 0 when Google gave none.
  final int priceLevel;
  final String category;
  final String summary;

  /// Null when Google did not say; never guessed.
  final bool? openNow;

  /// The venue's offset from UTC, which is how "today" is worked out in the
  /// venue's own time zone rather than the visitor's.
  final int? utcOffsetMinutes;

  /// Monday first, as Google returns them: "Monday: 4 PM – 2 AM".
  final List<String> openingHours;
  final List<PlaceReview> reviews;
  final List<PlacePhoto> photos;

  /// True when Google returned nothing the bubble could show.
  bool get isEmpty =>
      address.isEmpty &&
      phone.isEmpty &&
      website.isEmpty &&
      rating == null &&
      summary.isEmpty &&
      openingHours.isEmpty &&
      reviews.isEmpty &&
      photos.isEmpty;

  /// Today's line from [openingHours], in the venue's own day.
  ///
  /// Uses [utcOffsetMinutes] so a Mumbai venue viewed from Austin shows
  /// Mumbai's today. Null when the hours or the offset are missing, since a
  /// guess at the weekday would put the wrong line on screen.
  String? todaysHours({DateTime? now}) {
    final offset = utcOffsetMinutes;
    if (offset == null || openingHours.length != 7) return null;
    final local = (now ?? DateTime.now()).toUtc().add(
      Duration(minutes: offset),
    );
    return openingHours[local.weekday - 1];
  }

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) read) => [
      for (final item in (json[key] as List?) ?? const [])
        if (item is Map) read(item.map((k, v) => MapEntry(k.toString(), v))),
    ];
    return PlaceDetails(
      name: (json['name'] ?? '').toString(),
      address: (json['formatted_address'] ?? '').toString(),
      phone: (json['formatted_phone_number'] ?? '').toString(),
      website: (json['website'] ?? '').toString(),
      mapsUrl: (json['maps_url'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      priceLevel: (json['price_level'] as num?)?.toInt() ?? 0,
      category: (json['category'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      openNow: json['open_now'] as bool?,
      utcOffsetMinutes: (json['utc_offset_minutes'] as num?)?.toInt(),
      openingHours: [
        for (final line in (json['opening_hours'] as List?) ?? const [])
          line.toString(),
      ],
      reviews: list('reviews', PlaceReview.fromJson),
      photos: list('photos', PlacePhoto.fromJson),
    );
  }
}

/// A failed lookup: the gateway was unreachable, refused, or limited the call.
/// A venue Google does not know is not this; it is a null result.
class PlaceDetailsException implements Exception {
  const PlaceDetailsException(this.message);
  final String message;
  @override
  String toString() => 'PlaceDetailsException: $message';
}

/// Fetches one venue's details from the gateway's Places proxy.
///
/// The pin's [lat] and [lng] go along so the gateway searches around the pin;
/// a name alone ("Whisler's") matches places in other cities. The field list is
/// the gateway's own, so none is sent. Returns null when Google has no match,
/// and throws [PlaceDetailsException] when the call itself failed.
Future<PlaceDetails?> fetchPlaceDetails({
  required String placeName,
  required double lat,
  required double lng,
  http.Client? client,
}) async {
  final uri = Uri.parse('${AppConfig.gatewayBaseUrl}/api/v1/places/details')
      .replace(
        queryParameters: {
          'place_name': placeName,
          'lat': lat.toString(),
          'lng': lng.toString(),
        },
      );
  final http.Response resp;
  try {
    resp = await (client?.get(uri) ?? http.get(uri)).timeout(
      const Duration(seconds: 12),
    );
  } catch (error) {
    throw PlaceDetailsException('could not reach the gateway: $error');
  }
  if (resp.statusCode != 200) {
    throw PlaceDetailsException('the gateway answered ${resp.statusCode}');
  }
  final Object? data;
  try {
    data = jsonDecode(resp.body);
  } catch (_) {
    throw const PlaceDetailsException('the gateway sent an unreadable answer');
  }
  if (data is! Map || data['status'] != 'OK' || data['result'] is! Map) {
    return null;
  }
  return PlaceDetails.fromJson(
    (data['result'] as Map).map((k, v) => MapEntry(k.toString(), v)),
  );
}

/// Returns a data URI for a photo reference via the gateway proxy, or an empty
/// string when the picture could not be fetched.
Future<String> fetchPhotoUrl({
  required String photoRef,
  required int maxWidth,
  http.Client? client,
}) async {
  final uri = Uri.parse('${AppConfig.gatewayBaseUrl}/api/v1/places/photo')
      .replace(
        queryParameters: {
          'maxwidth': maxWidth.toString(),
          'photo_name': photoRef,
        },
      );
  try {
    final resp = await (client?.get(uri) ?? http.get(uri)).timeout(
      const Duration(seconds: 12),
    );
    if (resp.statusCode != 200) return '';
    final data = jsonDecode(resp.body);
    return data is Map ? (data['photo_data'] as String? ?? '') : '';
  } catch (_) {
    return '';
  }
}

/// A session cache of place lookups, so tapping a pin a second time shows its
/// bubble at once instead of calling the gateway again.
///
/// The cache holds the in-flight future, so two quick taps share one request.
/// A failed call is dropped from the cache so the next tap tries again; a
/// "Google has no such place" answer is kept, since asking again would only
/// spend another billed call on the same result.
class PlaceDetailsRepository {
  PlaceDetailsRepository({this.client});

  /// The one the map uses.
  static final PlaceDetailsRepository shared = PlaceDetailsRepository();

  final http.Client? client;
  final Map<String, Future<PlaceDetails?>> _details = {};
  final Map<String, Future<String>> _photos = {};

  static String _key(String name, double lat, double lng) =>
      '${name.trim().toLowerCase()}|${lat.toStringAsFixed(4)}|${lng.toStringAsFixed(4)}';

  /// The venue's details, or null when Google has none or the call failed.
  Future<PlaceDetails?> load({
    required String name,
    required double lat,
    required double lng,
  }) {
    final key = _key(name, lat, lng);
    final cached = _details[key];
    if (cached != null) return cached;
    // The cached future never errors, so a second tap during a failing call
    // gets the same null the first one does. A failure also leaves the cache
    // so the next tap tries again; a not-found answer stays.
    late final Future<PlaceDetails?> future;
    future =
        fetchPlaceDetails(
          placeName: name,
          lat: lat,
          lng: lng,
          client: client,
        ).then<PlaceDetails?>(
          (value) => value,
          onError: (Object _) {
            if (identical(_details[key], future)) _details.remove(key);
            return null;
          },
        );
    _details[key] = future;
    return future;
  }

  /// A photo's data URI, cached by reference and width.
  Future<String> photo(String ref, {int maxWidth = 640}) {
    final key = '$ref|$maxWidth';
    final cached = _photos[key];
    if (cached != null) return cached;
    final future = fetchPhotoUrl(
      photoRef: ref,
      maxWidth: maxWidth,
      client: client,
    );
    _photos[key] = future;
    future.then((url) {
      // An empty answer is a failure; let the next open retry it.
      if (url.isEmpty && identical(_photos[key], future)) _photos.remove(key);
    });
    return future;
  }
}
