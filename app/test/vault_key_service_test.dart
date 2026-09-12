import 'dart:io';
import 'dart:typed_data';

import 'package:e2ee_notes/src/vault_key_service.dart';
import 'package:e2ee_notes/src/vault_key_repository/plaintext_vault_key_repository.dart';
import 'package:e2ee_notes/src/vault_key_repository/vault_key_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';

final class MemoryVaultKeyRepository implements VaultKeyRepository {
  Uint8List? saved;
  bool corruptWrites = false;

  @override
  Future<bool> exists() async => saved != null;

  @override
  Future<Uint8List> read() async => Uint8List.fromList(saved!);

  @override
  Future<void> write(Uint8List bytes) async {
    saved = Uint8List.fromList(bytes);
    if (corruptWrites) saved![1] ^= 1;
  }
}

final class TestEncryptionKey implements EncryptionKey {
  int calls = 0;

  @override
  Future<Uint8List> encrypt(Uint8List plaintext) async {
    calls++;
    return Uint8List.fromList([42, ...plaintext.map((byte) => byte ^ 255)]);
  }
}

final class TestDecryptionKey implements DecryptionKey {
  @override
  Future<Uint8List> decrypt(Uint8List ciphertext) async {
    if (ciphertext.length != 33 || ciphertext.first != 42) {
      throw const FormatException('invalid test ciphertext');
    }
    return Uint8List.fromList(
      ciphertext.skip(1).map((byte) => byte ^ 255).toList(),
    );
  }
}

void main() {
  test(
    'existing key is decrypted without encrypting or replacing it',
    () async {
      final key = Uint8List(32);
      final encryption = TestEncryptionKey();
      final repository = MemoryVaultKeyRepository()
        ..saved = await encryption.encrypt(key);
      encryption.calls = 0;
      final service = VaultKeyService.protected(
        repository: repository,
        encryptionKey: encryption,
        decryptionKey: TestDecryptionKey(),
      );
      expect(await service.openKey(), key);
      expect(encryption.calls, 0);
    },
  );

  test(
    'repository receives ciphertext and a fresh service restores the key',
    () async {
      final repository = MemoryVaultKeyRepository();
      VaultKeyService service() => VaultKeyService.protected(
        repository: repository,
        encryptionKey: TestEncryptionKey(),
        decryptionKey: TestDecryptionKey(),
      );
      final key = await service().openKey();
      expect(repository.saved, isNot(key));
      expect(repository.saved, hasLength(33));
      expect(await service().openKey(), key);
    },
  );

  test('migration retains plaintext if persisted key does not match', () async {
    final root = await Directory.systemTemp.createTemp('key-migration-');
    addTearDown(() => root.delete(recursive: true));
    final source = PlaintextVaultKeyRepository(root);
    final key = Uint8List(32);
    await source.write(key);
    final repository = MemoryVaultKeyRepository()..corruptWrites = true;
    final service = VaultKeyService.protected(
      repository: repository,
      encryptionKey: TestEncryptionKey(),
      decryptionKey: TestDecryptionKey(),
      migrationSource: source,
    );
    await expectLater(service.openKey(), throwsFormatException);
    expect(await source.read(), key);
    await expectLater(service.openKey(), throwsFormatException);
    expect(await source.read(), key);
  });
}
