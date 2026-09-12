import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:e2ee_notes/src/local_vault.dart';
import 'package:e2ee_notes/src/vault_key_provider.dart';
import 'package:e2ee_notes/src/vault_key_storage/plaintext_file_vault_key_storage.dart';
import 'package:e2ee_notes/src/vault_key_storage/secure_enclave_vault_key_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_keys/hardware_keys.dart';
import 'package:notes_repository/notes_repository.dart';
import 'package:path/path.dart' as p;
import 'package:storage_filesystem/storage_filesystem.dart';

final class FakeHardwareKeys extends HardwareKeys {
  FakeHardwareKeys({
    this.available = true,
    this.hardwareBacked = true,
    this.corruptUnwrappedKey = false,
    this.beforeWrap,
  });

  final bool corruptUnwrappedKey;
  bool available;
  bool hardwareBacked;
  final Future<void> Function()? beforeWrap;

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
  }) async {
    await beforeWrap?.call();
    return VaultKeyEnvelope(
      version: 1,
      suite: recipient.suite,
      recipientKeyId: recipient.keyId,
      ephemeralPublicKey: 'test-ephemeral',
      sealedKey: base64Encode(vaultKey),
    );
  }

  @override
  Future<Uint8List> unwrapVaultKey({
    required Uint8List keyHandle,
    required VaultKeyEnvelope envelope,
  }) async {
    if (!available || !hardwareBacked) throw StateError('Hardware unavailable');
    final key = base64Decode(envelope.sealedKey);
    if (corruptUnwrappedKey) key[0] ^= 1;
    return key;
  }
}

VaultKeyProvider plaintextKeyProvider(Directory root) =>
    VaultKeyProvider(storage: PlaintextFileVaultKeyStorage(root));

VaultKeyProvider appleKeyProvider(Directory root, HardwareKeys hardware) =>
    VaultKeyProvider(
      storage: SecureEnclaveVaultKeyStorage(root, hardware),
      migrationSource: PlaintextFileVaultKeyStorage(root),
    );

void main() {
  test(
    'existing Apple key never falls back when hardware becomes unavailable',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'apple-unavailable-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final hardware = FakeHardwareKeys();
      final provider = appleKeyProvider(directory, hardware);
      final key = await provider.openKey();
      final envelope = File(p.join(directory.path, 'vault-key.envelope.json'));
      final savedEnvelope = await envelope.readAsBytes();
      hardware.available = false;
      await expectLater(provider.openKey(), throwsStateError);
      final plaintext = File(p.join(directory.path, 'vault-key.bin'));
      expect(await plaintext.exists(), isFalse);
      await plaintext.writeAsBytes(key);
      await expectLater(provider.openKey(), throwsStateError);
      expect(await plaintext.readAsBytes(), key);
      expect(await envelope.readAsBytes(), savedEnvelope);
    },
  );

  test(
    'Apple storage rejects TPM state even when hardware is unavailable',
    () async {
      final directory = await Directory.systemTemp.createTemp('apple-foreign-');
      addTearDown(() => directory.delete(recursive: true));
      await File(p.join(directory.path, 'vault-key.tpm')).writeAsBytes([1]);
      final provider = appleKeyProvider(
        directory,
        FakeHardwareKeys(available: false),
      );
      await expectLater(provider.openKey(), throwsFormatException);
      expect(
        await File(p.join(directory.path, 'vault-key.bin')).exists(),
        isFalse,
      );
    },
  );
  for (final failVerification in [false, true]) {
    test(
      'new hardware key stays off plaintext disk, failure: $failVerification',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'e2ee-new-key-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final plaintextKey = File(p.join(directory.path, 'vault-key.bin'));
        final provider = appleKeyProvider(
          directory,
          FakeHardwareKeys(
            corruptUnwrappedKey: failVerification,
            beforeWrap: () async =>
                expect(await plaintextKey.exists(), isFalse),
          ),
        );
        if (failVerification) {
          await expectLater(provider.openKey(), throwsFormatException);
        } else {
          final key = await provider.openKey();
          expect(key, hasLength(32));
          expect(await provider.openKey(), key);
        }
        expect(await plaintextKey.exists(), isFalse);
      },
    );
  }

  test('rejects an invalid software key without replacing it', () async {
    final directory = await Directory.systemTemp.createTemp(
      'e2ee-invalid-key-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final plaintextKey = File(p.join(directory.path, 'vault-key.bin'));
    await plaintextKey.writeAsBytes([1, 2, 3]);
    final provider = appleKeyProvider(directory, FakeHardwareKeys());
    await expectLater(provider.openKey(), throwsFormatException);
    expect(await plaintextKey.readAsBytes(), [1, 2, 3]);
    expect(
      await File(p.join(directory.path, 'recipient-key.handle')).exists(),
      isFalse,
    );
  });

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
    const softwareVault = LocalVault(keyProviderFactory: plaintextKeyProvider);
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
      keyProviderFactory: (root) => appleKeyProvider(root, FakeHardwareKeys()),
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
      keyProviderFactory: (root) => appleKeyProvider(root, FakeHardwareKeys()),
    ).openAt(directory);
    expect((await reopened.loadNotes()).single.title, 'Migrated');
  });

  for (final capabilities in [(false, true), (true, false)]) {
    test('Apple fallback preserves the key for $capabilities', () async {
      final directory = await Directory.systemTemp.createTemp('e2ee-fallback-');
      addTearDown(() => directory.delete(recursive: true));
      const softwareVault = LocalVault(
        keyProviderFactory: plaintextKeyProvider,
      );
      final original = await softwareVault.openAt(directory);
      await original.save(title: 'Existing', body: 'Keep this note');
      final keyFile = File(p.join(directory.path, 'vault-key.bin'));
      final originalKey = await keyFile.readAsBytes();
      final reopened = await LocalVault(
        keyProviderFactory: (root) => appleKeyProvider(
          root,
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
    final key = await plaintextKeyProvider(directory).openKey();
    await File(p.join(directory.path, 'recipient-key.handle'))
        .writeAsBytes([1]);
    final vault = LocalVault(
      keyProviderFactory: (root) => appleKeyProvider(root, FakeHardwareKeys()),
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

  test('failed wrap verification preserves the software key', () async {
    final directory = await Directory.systemTemp.createTemp('e2ee-verify-');
    addTearDown(() => directory.delete(recursive: true));
    final key = await plaintextKeyProvider(directory).openKey();
    final provider = appleKeyProvider(
      directory,
      FakeHardwareKeys(corruptUnwrappedKey: true),
    );
    await expectLater(provider.openKey(), throwsFormatException);
    expect(
      await File(p.join(directory.path, 'vault-key.bin')).readAsBytes(),
      key,
    );
    expect(
      await File(p.join(directory.path, 'recipient-key.handle')).exists(),
      isFalse,
    );
    expect(
      await File(p.join(directory.path, 'vault-key.envelope.json')).exists(),
      isFalse,
    );
  });

  for (final matching in [true, false]) {
    test(
      'reopening removes a leftover software key only when matching: $matching',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'e2ee-leftover-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final provider = appleKeyProvider(directory, FakeHardwareKeys());
        final key = await provider.openKey();
        final leftover = Uint8List.fromList(key);
        if (!matching) leftover[0] ^= 1;
        final softwareFile = File(p.join(directory.path, 'vault-key.bin'));
        await softwareFile.writeAsBytes(leftover);
        if (matching) {
          expect(await provider.openKey(), key);
          expect(await softwareFile.exists(), isFalse);
        } else {
          await expectLater(provider.openKey(), throwsFormatException);
          expect(await softwareFile.readAsBytes(), leftover);
        }
      },
    );
  }
}
