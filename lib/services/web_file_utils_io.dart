import 'dart:typed_data';

/// Stub implementation for non-web platforms.
Future<void> downloadFileWeb(Uint8List bytes, String filename) async {
  throw UnsupportedError('downloadFileWeb is only supported on web');
}
