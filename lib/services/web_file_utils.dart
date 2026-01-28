// Web-specific helper to trigger a download or open blob. This file is only used on web via conditional imports.
// Implementation uses dart:html which is only available on web.

import 'dart:typed_data';
import 'dart:html' as html;

Future<void> downloadFileWeb(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..style.display = 'none'
    ..download = filename;
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
