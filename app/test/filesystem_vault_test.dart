import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:e2ee_notes/src/local_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_keys/hardware_keys.dart';
import 'package:notes_repository/notes_repository.dart';
import 'package:storage_filesystem/storage_filesystem.dart';

final class FakeHardwareKeys extends HardwareKeys {
  @override
  Future<HardwareKeyCapabilities> capabilities() async =>
      const HardwareKeyCapabilities(
        available: true,
        hardwareBacked: true,
        provider: 'Test hardware',
      );

  @override
  Future<RecipientKey> createRecipientKey({
    bool requireUserPresence = false,
  }) async => RecipientKey(
    handle: Uint8List.fromList([1, 2, 3]),
    publicKey: const RecipientPublicKey(
      version: 1,
      suite: 'test-suite',
      keyId: 'test-key',
      publicKey: 'test-public',
    ),
  );

  @override
  Future<VaultKeyEnvelope> wrapVaultKey({
    required Uint8List vaultKey,
    required RecipientPublicKey recipient,
  }) async => VaultKeyEnvelope(
    version: 1,
    suite: recipient.suite,
    recipientKeyId: recipient.keyId,
    ephemeralPublicKey: 'test-ephemeral',
    sealedKey: base64Encode(vaultKey),
  );

  @override
  Future<Uint8List> unwrapVaultKey({
    required Uint8List keyHandle,
    required VaultKeyEnvelope envelope,
  }) async => base64Decode(envelope.sealedKey);
}

void main() {
  test('encrypted note survives reopening a filesystem store', () async {
    final directory = await Directory.systemTemp.createTemp(
      'e2ee-notes-vault-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final deviceId = 'b' * 64;

    final first = EncryptedNotesRepository(
      store: FilesystemBlobStore(directory),
      vaultKey: key,
      deviceId: deviceId,
    );
    await first.save(title: 'Filesystem title', body: 'Filesystem secret');

    final files = await directory
        .list(recursive: true)
        .where((entry) => entry is File)
        .toList();
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

  test('migrates a software key to a verified hardware envelope', () async {
    final directory = await Directory.systemTemp.createTemp(
      'e2ee-notes-migrate-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final legacyKey = File(
      '${directory.path}${Platform.pathSeparator}vault-key.bin',
    );
    await legacyKey.writeAsBytes(
      Uint8List.fromList(List<int>.generate(32, (i) => i)),
    );

    final repository = await LocalVault.openAt(
      directory,
      hardwareKeys: FakeHardwareKeys(),
      enableHardwareForTesting: true,
    );
    await repository.save(title: 'Migrated', body: 'Still readable');

    expect(await legacyKey.exists(), isFalse);
    expect(
      await File(
        '${directory.path}${Platform.pathSeparator}recipient-key.handle',
      ).exists(),
      isTrue,
    );
    expect(
      await File(
        '${directory.path}${Platform.pathSeparator}vault-key.envelope.json',
      ).exists(),
      isTrue,
    );

    final reopened = await LocalVault.openAt(
      directory,
      hardwareKeys: FakeHardwareKeys(),
      enableHardwareForTesting: true,
    );
    expect((await reopened.loadNotes()).single.title, 'Migrated');
  });
}
