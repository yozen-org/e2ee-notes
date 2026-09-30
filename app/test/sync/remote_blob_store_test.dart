import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:e2ee_notes/storage/blob_store.dart';
import 'package:e2ee_notes/sync/remote_blob_store.dart';

void main() {
  const baseUrl = 'https://e2eenotes.yozen.org';
  const namespace = 'abc123';

  test('get fetches an object and namespaces the key', () async {
    final store = RemoteBlobStore(
      baseUrl: baseUrl,
      namespace: namespace,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          '$baseUrl/v1/objects/$namespace/rooms/r/operations/o.json',
        );
        return http.Response.bytes([1, 2, 3], 200);
      }),
    );

    expect(await store.get('rooms/r/operations/o.json'), [1, 2, 3]);
  });

  test('get throws ObjectNotFound on 404', () async {
    final store = RemoteBlobStore(
      baseUrl: baseUrl,
      namespace: namespace,
      client: MockClient((request) async => http.Response('', 404)),
    );

    await expectLater(store.get('missing'), throwsA(isA<ObjectNotFound>()));
  });

  test('putIfAbsent uploads the object body', () async {
    final store = RemoteBlobStore(
      baseUrl: baseUrl,
      namespace: namespace,
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.bodyBytes, [9, 8, 7]);
        expect(
          request.url.toString(),
          '$baseUrl/v1/objects/$namespace/rooms/r/operations/o.json',
        );
        return http.Response('', 200);
      }),
    );

    await store.putIfAbsent(
      'rooms/r/operations/o.json',
      Uint8List.fromList([9, 8, 7]),
    );
  });

  test('list strips the namespace prefix', () async {
    final store = RemoteBlobStore(
      baseUrl: baseUrl,
      namespace: namespace,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/objects');
        expect(request.url.queryParameters['prefix'], '$namespace/rooms/');
        return http.Response(
          jsonEncode(['$namespace/rooms/a.json', '$namespace/rooms/b.json']),
          200,
        );
      }),
    );

    expect(await store.list('rooms/'), ['rooms/a.json', 'rooms/b.json']);
  });

  test('delete removes an object', () async {
    final store = RemoteBlobStore(
      baseUrl: baseUrl,
      namespace: namespace,
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        return http.Response('', 204);
      }),
    );

    await store.delete('rooms/r/operations/o.json');
  });
}
