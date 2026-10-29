/// Shares a URL, falling back to the clipboard when the Web Share API is not
/// available (desktop, or a browser without `navigator.share`).
///
/// Returns true when the URL was shared or copied.
library;

export 'share_web.dart' if (dart.library.io) 'share_nonweb.dart';
