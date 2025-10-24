import 'dart:typed_data';

// Non-web platforms: no-op function to keep compile-time imports clean
Future<void> triggerDownload(Uint8List bytes, String contentType, String filename) async {
  // Intentionally left blank. Mobile/desktop saving can be implemented later.
}