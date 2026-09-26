import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:e2ee_notes/notes/room.dart';
import 'package:e2ee_notes/notes/room_key.dart';
import 'package:e2ee_notes/storage/blob_store.dart';
import 'package:flutter_test/flutter_test.dart';

final class MemoryStore implements BlobStore {
  final objects = <String, Uint8List>{};

  @override
  Future<void> delete(String key) async => objects.remove(key);

  @override
  Future<Uint8List> get(String key) async {
    final value = objects[key];
    if (value == null) throw ObjectNotFound(key);
    return Uint8List.fromList(value);
  }

  @override
  Future<List<String>> list(String prefix) async =>
      objects.keys.where((key) => key.startsWith(prefix)).toList()..sort();

  @override
  Future<void> putIfAbsent(String key, Uint8List value) async {
    if (objects.containsKey(key)) throw ObjectConflict(key);
    objects[key] = Uint8List.fromList(value);
  }
}

void main() {
  final rootKey = Uint8List.fromList(List<int>.generate(32, (index) => index));

  test('creates a room key once and restores it on reopen', () async {
    final store = MemoryStore();
    final first = await RoomKeyStore(
      store: store,
      rootKey: rootKey,
      random: Random(7),
    ).loadOrCreate();
    expect(first.id, personalRoomId);
    expect(first.key, hasLength(32));

    final reopened = await RoomKeyStore(
      store: store,
      rootKey: rootKey,
    ).loadOrCreate();
    expect(reopened.key, first.key);
  });

  test('stores the room key encrypted, not in the clear', () async {
    final store = MemoryStore();
    final room = await RoomKeyStore(
      store: store,
      rootKey: rootKey,
      random: Random(7),
    ).loadOrCreate();

    final persisted = utf8.decode(
      store.objects['rooms/$personalRoomId/room-key.json']!,
    );
    expect(persisted, isNot(contains(base64Encode(room.key))));
    expect(
      jsonDecode(persisted),
      containsPair('suite', 'AES-256-GCM'),
    );
  });

  test('fails to open a room with a different root key', () async {
    final store = MemoryStore();
    await RoomKeyStore(
      store: store,
      rootKey: rootKey,
      random: Random(7),
    ).loadOrCreate();

    final wrongKey = Uint8List.fromList(
      List<int>.generate(32, (index) => index ^ 0xff),
    );
    await expectLater(
      RoomKeyStore(store: store, rootKey: wrongKey).loadOrCreate(),
      throwsA(anything),
    );
  });
}
