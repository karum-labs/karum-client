import 'package:flutter/services.dart';

/// Non-web implementation: Web Share is unavailable, so copy to the
/// clipboard instead.
Future<bool> shareUrl({
  required String url,
  required String title,
  String? text,
}) async {
  return copyUrl(url);
}

/// Copies [url] to the clipboard. Works on every platform.
Future<bool> copyUrl(String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  return true;
}

/// The public web app origin, set at build time with
/// `--dart-define=PUBLIC_APP_URL=https://app.example`.
const _publicAppUrl = String.fromEnvironment('PUBLIC_APP_URL');

/// Builds a link to an in-app route. Desktop builds have no browser origin,
/// so they use the configured public app URL; without one the route is
/// returned as-is rather than inventing a host.
String appUrl(String path) {
  final route = path.startsWith('/') ? path : '/$path';
  if (_publicAppUrl.isEmpty) {
    return route;
  }
  return Uri.parse(_publicAppUrl).replace(fragment: route).toString();
}
