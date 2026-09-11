// 暗号化した履歴からの復元、論理削除、改ざん時の失敗を確認する。
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_repository/notes_repository.dart';
import 'package:storage_api/storage_api.dart';

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
  final vaultKey = Uint8List.fromList(List<int>.generate(32, (index) => index));
  final deviceId = 'd' * 64;

  test(
    'stores only encrypted immutable operations and rebuilds notes',
    () async {
      final store = MemoryStore();
      final repository = EncryptedNotesRepository(
        store: store,
        vaultKey: vaultKey,
        deviceId: deviceId,
        random: Random(7),
        clock: () => DateTime.utc(2026, 9, 7),
      );

      final created = await repository.save(
        title: 'Private',
        body: 'secret body',
      );
      await repository.save(
        noteId: created.id,
        title: 'Updated',
        body: 'new body',
      );

      expect(store.objects, hasLength(2));
      expect(store.objects.keys, everyElement(startsWith('operations/')));
      final persisted = store.objects.values.map(utf8.decode).join();
      expect(persisted, isNot(contains('Private')));
      expect(persisted, isNot(contains('secret body')));
      expect(persisted, isNot(contains('Updated')));
      expect(persisted, isNot(contains('new body')));

      final reopened = EncryptedNotesRepository(
        store: store,
        vaultKey: vaultKey,
        deviceId: deviceId,
      );
      final notes = await reopened.loadNotes();
      expect(notes, hasLength(1));
      expect(notes.single.title, 'Updated');
      expect(notes.single.body, 'new body');
    },
  );

  test('delete appends a tombstone and removes note from projection', () async {
    final store = MemoryStore();
    final repository = EncryptedNotesRepository(
      store: store,
      vaultKey: vaultKey,
      deviceId: deviceId,
      random: Random(9),
    );
    final note = await repository.save(title: 'Delete me', body: 'body');
    await repository.delete(note.id);

    expect(await repository.loadNotes(), isEmpty);
    expect(store.objects, hasLength(2));
  });

  test('fails closed when an encrypted operation is modified', () async {
    final store = MemoryStore();
    final repository = EncryptedNotesRepository(
      store: store,
      vaultKey: vaultKey,
      deviceId: deviceId,
      random: Random(11),
    );
    await repository.save(title: 'Title', body: 'Body');
    final key = store.objects.keys.single;
    final envelope =
        jsonDecode(utf8.decode(store.objects[key]!)) as Map<String, dynamic>;
    final ciphertext = base64Decode(envelope['ciphertext'] as String);
    ciphertext[0] ^= 1;
    envelope['ciphertext'] = base64Encode(ciphertext);
    store.objects[key] = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));

    await expectLater(repository.loadNotes(), throwsA(anything));
  });
}
