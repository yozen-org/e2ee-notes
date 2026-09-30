import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../storage/blob_store.dart';

/// A [BlobStore] backed by the exchange server (`spec/EXCHANGE_SERVER_V1.md`).
///
/// Object keys are namespaced with [namespace], so this vault's objects do not
/// collide with any other vault on the same server.
final class RemoteBlobStore implements BlobStore {
  RemoteBlobStore({
    required this.baseUrl,
    required this.namespace,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String namespace;
  final http.Client _client;

  @override
  Future<Uint8List> get(String key) async {
    final response = await _client.get(_objectUri(key));
    if (response.statusCode == 404) throw ObjectNotFound(key);
    if (response.statusCode != 200) throw StorageFailure(key);
    return response.bodyBytes;
  }

  @override
  Future<void> putIfAbsent(String key, Uint8List value) async {
    final response = await _client.put(_objectUri(key), body: value);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StorageFailure(key);
    }
  }

  @override
  Future<List<String>> list(String prefix) async {
    final response = await _client.get(_listUri(prefix));
    if (response.statusCode != 200) throw StorageFailure(prefix);
    final keys = (jsonDecode(response.body) as List).cast<String>();
    return keys.map((key) => key.substring(namespace.length + 1)).toList();
  }

  @override
  Future<void> delete(String key) async {
    final response = await _client.delete(_objectUri(key));
    if (response.statusCode == 404) throw ObjectNotFound(key);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw StorageFailure(key);
    }
  }

  Uri _objectUri(String key) => Uri.parse('$baseUrl/v1/objects/$namespace/$key');

  Uri _listUri(String prefix) =>
      Uri.parse('$baseUrl/v1/objects').replace(
        queryParameters: {'prefix': '$namespace/$prefix'},
      );
}
