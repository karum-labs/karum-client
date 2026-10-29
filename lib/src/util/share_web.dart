// This file is selected only on the web by `share.dart`'s conditional
// export. The `dart:html` APIs are still the smallest dependency-free way to
// reach the Web Share API and the clipboard here, so suppress the two
// Flutter-web lints at the file boundary.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation: tries the Web Share API, then falls back to the
/// clipboard.
Future<bool> shareUrl({
  required String url,
  required String title,
  String? text,
}) async {
  try {
    await html.window.navigator.share({
      'title': title,
      'text': text ?? title,
      'url': url,
    });
    return true;
  } catch (_) {
    // The user dismissed the share sheet, or sharing is not permitted;
    // fall through to the clipboard.
  }
  return copyUrl(url);
}

/// Copies [url] to the clipboard on web.
Future<bool> copyUrl(String url) async {
  await html.window.navigator.clipboard?.writeText(url);
  return true;
}

/// Builds a link to an in-app route on the running web app.
///
/// The client uses Flutter's default hash URL strategy, so the route goes in
/// the fragment: `https://app.example/#/scout/run-0041`. A shared link must
/// point at the app, never at the gateway's JSON API.
String appUrl(String path) {
  final route = path.startsWith('/') ? path : '/$path';
  return Uri.base.replace(fragment: route).toString();
}
