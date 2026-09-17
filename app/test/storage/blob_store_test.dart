import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:e2ee_notes/storage/blob_store.dart';

final class MemoryStore implements BlobStore {
  final objects = <String, Uint8List>{};

  @override
  Future<void> delete(String key) async => objects.remove(key);

  @override
  Future<Uint8List> get(String key) async => objects[key]!;

  @override
  Future<List<String>> list(String prefix) async =>
      objects.keys.where((key) => key.startsWith(prefix)).toList();

  @override
  Future<void> putIfAbsent(String key, Uint8List value) async {
    objects.putIfAbsent(key, () => value);
  }
}

void main() {
  test('storage contract can hold opaque bytes', () async {
    final store = MemoryStore();
    await store.putIfAbsent('operations/a', Uint8List.fromList([1, 2, 3]));
    expect(await store.get('operations/a'), [1, 2, 3]);
    expect(await store.list('operations/'), ['operations/a']);
  });
}
