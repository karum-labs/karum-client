import 'dart:io';
import 'dart:typed_data';

/// Writes the generated PDF beside the app's working directory on desktop.
Future<void> saveBytesImpl(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
}) async {
  final file = File(
    '${Directory.current.path}${Platform.pathSeparator}$filename',
  );
  await file.writeAsBytes(bytes, flush: true);
}
