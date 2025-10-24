// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> triggerDownload(Uint8List bytes, String contentType, String filename) async {
  final blob = html.Blob([bytes], contentType);
  final dlUrl = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: dlUrl)..download = filename;
  a.click();
  html.Url.revokeObjectUrl(dlUrl);
}