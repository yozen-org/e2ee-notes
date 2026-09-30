import 'dart:convert';

import 'package:http/http.dart' as http;

/// A short-lived transfer handle returned by an exchange server.
final class ExchangeTransfer {
  const ExchangeTransfer({required this.url, required this.expiresAt});

  final String url;
  final String expiresAt;
}

/// Client for the exchange-server protocol (`spec/EXCHANGE_SERVER_V1.md`).
///
/// Uploads and downloads opaque payloads. The server cannot read them.
final class ExchangeClient {
  ExchangeClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<ExchangeTransfer> upload(String payload) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/transfers'),
      headers: const {'Content-Type': 'application/json'},
      body: payload,
    );
    if (response.statusCode != 201) {
      throw ExchangeException('upload failed (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ExchangeTransfer(
      url: body['url'] as String,
      expiresAt: body['expiresAt'] as String,
    );
  }

  Future<String> download(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw ExchangeException('download failed (${response.statusCode})');
    }
    return response.body;
  }
}

final class ExchangeException implements Exception {
  const ExchangeException(this.message);
  final String message;

  @override
  String toString() => 'ExchangeException: $message';
}
