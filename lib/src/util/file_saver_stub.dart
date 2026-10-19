import 'dart:typed_data';

/// Stub used when neither `dart:io` nor JS interop is available.
Future<void> saveBytesImpl(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
}) {
  throw UnsupportedError('Saving files is not supported on this platform.');
}
