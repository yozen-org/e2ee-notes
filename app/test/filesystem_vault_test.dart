import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_repository/notes_repository.dart';
import 'package:storage_filesystem/storage_filesystem.dart';

void main() {
  test('encrypted note survives reopening a filesystem store', () async {
    final directory = await Directory.systemTemp.createTemp('e2ee-notes-vault-');
    addTearDown(() => directory.delete(recursive: true));
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final deviceId = 'b' * 64;

    final first = EncryptedNotesRepository(
      store: FilesystemBlobStore(directory),
      vaultKey: key,
      deviceId: deviceId,
    );
    await first.save(title: 'Filesystem title', body: 'Filesystem secret');

    final files = await directory.list(recursive: true).where((entry) => entry is File).toList();
    expect(files, hasLength(1));
    final persisted = await (files.single as File).readAsString();
    expect(persisted, isNot(contains('Filesystem title')));
    expect(persisted, isNot(contains('Filesystem secret')));

    final reopened = EncryptedNotesRepository(
      store: FilesystemBlobStore(directory),
      vaultKey: key,
      deviceId: deviceId,
    );
    final notes = await reopened.loadNotes();
    expect(notes.single.title, 'Filesystem title');
    expect(notes.single.body, 'Filesystem secret');
  });
}
