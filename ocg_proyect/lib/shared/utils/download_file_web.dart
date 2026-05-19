// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<bool> downloadFileUrl(String url, {required String fileName}) async {
  try {
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..target = '_self'
      ..rel = 'noopener';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  }
}
