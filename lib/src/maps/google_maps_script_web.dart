import 'dart:async';

import 'package:web/web.dart' as web;

Future<void>? _pending;

/// Loads the Maps JavaScript API once. The key is restricted to that API.
Future<void> ensureGoogleMapsLoaded(String apiKey) {
  if (apiKey.isEmpty) return Future.value();
  final existing = _pending;
  if (existing != null) return existing;
  final created = _load(apiKey);
  _pending = created;
  return created;
}

Future<void> _load(String apiKey) async {
  final prior = web.document.getElementById('karum-google-maps');
  if (prior != null) return;
  final script = web.HTMLScriptElement()
    ..id = 'karum-google-maps'
    ..async = true
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeQueryComponent(apiKey)}';
  final done = Completer<void>();
  script.onLoad.listen((_) {
    if (!done.isCompleted) done.complete();
  });
  script.onError.listen((_) {
    if (!done.isCompleted) {
      done.completeError(
        StateError('Google Maps JavaScript API failed to load'),
      );
    }
  });
  web.document.head!.append(script);
  await done.future;
}
