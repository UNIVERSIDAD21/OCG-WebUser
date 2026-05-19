import 'package:url_launcher/url_launcher.dart';

Future<bool> downloadFileUrl(String url, {required String fileName}) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
