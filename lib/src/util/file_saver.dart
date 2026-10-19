import 'dart:typed_data';

import 'file_saver_stub.dart'
    if (dart.library.js_interop) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';

/// Saves bytes as a download on web or a file on desktop.
Future<void> saveBytes(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
}) => saveBytesImpl(bytes, filename: filename, mimeType: mimeType);
