import 'package:url_launcher/url_launcher.dart';

/// Opens an external citation or venue website in a new tab/window.
///
/// The caller decides what to show when this returns false; no navigation state
/// is mutated here.
Future<bool> openExternal(String value) async {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
