import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:e2ee_notes/src/local_vault.dart';
import 'package:e2ee_notes/src/vault_key_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_keys/hardware_keys.dart';
import 'package:notes_repository/notes_repository.dart';
import 'package:path/path.dart' as p;
import 'package:storage_filesystem/storage_filesystem.dart';

final class FakeHardwareKeys extends HardwareKeys {
  FakeHardwareKeys({this.available = true, this.hardwareBacked = true});

  final bool available;
  final bool hardwareBacked;

  @override
  Future<HardwareKeyCapabilities> capabilities() async =>
      HardwareKeyCapabilities(
        available: available,
        hardwareBacked: hardwareBacked,
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
    const softwareVault = LocalVault(keyProvider: SoftwareVaultKeyProvider());
    final original = await softwareVault.openAt(directory);
    await original.save(title: 'Before migration', body: 'Existing secret');
    final deviceFile = File(p.join(directory.path, 'device-id.bin'));
    final deviceId = await deviceFile.readAsBytes();
    final legacyKey = File(p.join(directory.path, 'vault-key.bin'));
    final keyBeforeMigration = await legacyKey.readAsBytes();
    final softwareReopened = await softwareVault.openAt(directory);
    expect((await softwareReopened.loadNotes()).single.body, 'Existing secret');
    expect(await legacyKey.readAsBytes(), keyBeforeMigration);

    final repository = await LocalVault(
      keyProvider: AppleVaultKeyProvider(FakeHardwareKeys()),
    ).openAt(directory);
    final migratedNote = (await repository.loadNotes()).single;
    expect(migratedNote.title, 'Before migration');
    await repository.save(
      noteId: migratedNote.id,
      title: 'Migrated',
      body: 'Still readable',
    );
    expect(await deviceFile.readAsBytes(), deviceId);

    expect(await legacyKey.exists(), isFalse);
    expect(
      await File(p.join(directory.path, 'recipient-key.handle')).exists(),
      isTrue,
    );
    expect(
      await File(p.join(directory.path, 'vault-key.envelope.json')).exists(),
      isTrue,
    );

    final reopened = await LocalVault(
      keyProvider: AppleVaultKeyProvider(FakeHardwareKeys()),
    ).openAt(directory);
    expect((await reopened.loadNotes()).single.title, 'Migrated');
  });

  for (final capabilities in [(false, true), (true, false)]) {
    test('Apple fallback preserves the key for $capabilities', () async {
      final directory = await Directory.systemTemp.createTemp('e2ee-fallback-');
      addTearDown(() => directory.delete(recursive: true));
      const softwareVault = LocalVault(keyProvider: SoftwareVaultKeyProvider());
      final original = await softwareVault.openAt(directory);
      await original.save(title: 'Existing', body: 'Keep this note');
      final keyFile = File(p.join(directory.path, 'vault-key.bin'));
      final originalKey = await keyFile.readAsBytes();
      final reopened = await LocalVault(
        keyProvider: AppleVaultKeyProvider(
          FakeHardwareKeys(
            available: capabilities.$1,
            hardwareBacked: capabilities.$2,
          ),
        ),
      ).openAt(directory);
      expect((await reopened.loadNotes()).single.body, 'Keep this note');
      expect(await keyFile.readAsBytes(), originalKey);
      expect(
        await File(p.join(directory.path, 'recipient-key.handle')).exists(),
        isFalse,
      );
    });
  }

  test('rejects incomplete hardware state without replacing the key', () async {
    final directory = await Directory.systemTemp.createTemp('e2ee-incomplete-');
    addTearDown(() => directory.delete(recursive: true));
    final key = await const SoftwareVaultKeyProvider().openKey(directory);
    await File(p.join(directory.path, 'recipient-key.handle'))
        .writeAsBytes([1]);
    final vault = LocalVault(
      keyProvider: AppleVaultKeyProvider(FakeHardwareKeys()),
    );
    await expectLater(vault.openAt(directory), throwsFormatException);
    expect(
      await File(p.join(directory.path, 'vault-key.bin')).readAsBytes(),
      key,
    );
    expect(
      await File(p.join(directory.path, 'vault-key.envelope.json')).exists(),
      isFalse,
    );
  });
}
