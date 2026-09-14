import 'dart:typed_data';

import 'package:secure_keys/secure_keys.dart';

import 'generate_random_bytes.dart';
import 'vault_key_repository/plaintext_vault_key_repository.dart';
import 'vault_key_repository/vault_key_repository.dart';
import 'vault_key_validation.dart';

final class VaultKeyService {
  const VaultKeyService.protected({
    required this.repository,
    required EncryptionKey this.encryptionKey,
    required DecryptionKey this.decryptionKey,
    this.migrationSource,
  });

  const VaultKeyService.plaintext({
    required PlaintextVaultKeyRepository this.repository,
  }) : migrationSource = null,
       encryptionKey = null,
       decryptionKey = null;

  final VaultKeyRepository repository;
  final PlaintextVaultKeyRepository? migrationSource;
  final EncryptionKey? encryptionKey;
  final DecryptionKey? decryptionKey;

  Future<Uint8List> openKey() async {
    if (await repository.exists()) return _restoreKey();
    if (await migrationSource?.exists() ?? false) return _migrateKey();
    return _createKey();
  }

  Future<Uint8List> _readKey() async {
    final bytes = await repository.read();
    final key = await decryptionKey?.decrypt(bytes) ?? bytes;
    validateVaultKey(key);
    return key;
  }

  Future<Uint8List> _restoreKey() async {
    final key = await _readKey();
    await _removeMigratedPlaintextKey(key);
    return key;
  }

  Future<void> _removeMigratedPlaintextKey(Uint8List key) async {
    final source = migrationSource;
    if (source == null || !await source.exists()) return;
    requireMatchingVaultKeys(key, await source.read());
    await source.delete();
  }

  Future<Uint8List> _migrateKey() async {
    final key = await migrationSource!.read();
    await _persistAndVerifyKey(key);
    await _removeMigratedPlaintextKey(key);
    return key;
  }

  Future<Uint8List> _createKey() async {
    final key = generateRandomBytes(32);
    await _persistAndVerifyKey(key);
    return key;
  }

  Future<void> _persistAndVerifyKey(Uint8List key) async {
    final bytes = await _protectAndVerifyKey(key);
    await repository.write(bytes);
    requireMatchingVaultKeys(key, await _readKey());
  }

  Future<Uint8List> _protectAndVerifyKey(Uint8List key) async {
    final encryptor = encryptionKey;
    if (encryptor == null) return key;
    final ciphertext = await encryptor.encrypt(key);
    requireMatchingVaultKeys(key, await decryptionKey!.decrypt(ciphertext));
    return ciphertext;
  }
}
