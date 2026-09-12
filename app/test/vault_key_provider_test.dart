import 'dart:io';
import 'dart:typed_data';

import 'package:e2ee_notes/src/vault_key_provider.dart';
import 'package:e2ee_notes/src/vault_key_storage/plaintext_file_vault_key_storage.dart';
import 'package:e2ee_notes/src/vault_key_storage/vault_key_storage.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeVaultKeyStorage implements VaultKeyStorage {
  Uint8List? saved;
  bool available = true;
  bool corruptWrites = false;
  int availabilityChecks = 0;

  @override
  Future<bool> exists() async => saved != null;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return available;
  }

  @override
  Future<Uint8List> read() async => Uint8List.fromList(saved!);

  @override
  Future<void> write(Uint8List key) async {
    saved = Uint8List.fromList(key);
    if (corruptWrites) saved![0] ^= 1;
  }
}

void main() {
  test(
    'existing data is read without checking creation availability',
    () async {
      final storage = FakeVaultKeyStorage()
        ..saved = Uint8List(32)
        ..available = false;
      expect(await VaultKeyProvider(storage: storage).openKey(), Uint8List(32));
      expect(storage.availabilityChecks, 0);
    },
  );

  test('migration retains plaintext if persisted key does not match', () async {
    final root = await Directory.systemTemp.createTemp('key-migration-');
    addTearDown(() => root.delete(recursive: true));
    final source = PlaintextFileVaultKeyStorage(root);
    final key = Uint8List(32);
    await source.write(key);
    final storage = FakeVaultKeyStorage()..corruptWrites = true;
    final provider = VaultKeyProvider(
      storage: storage,
      migrationSource: source,
    );
    await expectLater(provider.openKey(), throwsFormatException);
    expect(await source.read(), key);
    await expectLater(provider.openKey(), throwsFormatException);
    expect(await source.read(), key);
  });

  test(
    'unavailable storage without fallback fails without creating a key',
    () async {
      final storage = FakeVaultKeyStorage()..available = false;
      await expectLater(
        VaultKeyProvider(storage: storage).openKey(),
        throwsStateError,
      );
      expect(storage.saved, isNull);
    },
  );
}
