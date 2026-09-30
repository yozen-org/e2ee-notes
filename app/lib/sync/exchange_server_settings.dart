import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'sync_vault.dart' show exchangeServerUrl;

/// Loads the configured exchange server URL, falling back to the default.
Future<String> loadExchangeServerUrl() async {
  final file = await _settingsFile();
  if (!await file.exists()) return exchangeServerUrl;
  final url = (await file.readAsString()).trim();
  return url.isEmpty ? exchangeServerUrl : url;
}

/// Persists the exchange server URL chosen by the user.
Future<void> saveExchangeServerUrl(String url) async {
  final file = await _settingsFile();
  await file.writeAsString(url.trim(), flush: true);
}

Future<File> _settingsFile() async {
  final support = await getApplicationSupportDirectory();
  return File(p.join(support.path, 'exchange-server-url'));
}
