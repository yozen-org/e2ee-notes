import 'dart:typed_data';

import 'generate_random_bytes.dart';
import 'vault_key_storage/plaintext_file_vault_key_storage.dart';
import 'vault_key_storage/vault_key_storage.dart';
import 'vault_key_validation.dart';

final class VaultKeyProvider {
  const VaultKeyProvider({required this.storage, this.migrationSource});

  final VaultKeyStorage storage;
  final PlaintextFileVaultKeyStorage? migrationSource;

  Future<Uint8List> openKey() async {
    if (await storage.exists()) return _restoreKey();
    if (!await storage.isAvailable()) return _openFallbackKey();
    if (await migrationSource?.exists() ?? false) return _migrateKey();
    return _createKey(storage);
  }

  Future<Uint8List> _restoreKey() async {
    final key = await storage.read();
    validateVaultKey(key);
    await migrationSource?.removeIfMatching(key);
    return key;
  }

  Future<Uint8List> _openFallbackKey() async {
    final fallback = migrationSource;
    if (fallback == null) throw StateError('vault-key storage is unavailable');
    if (await fallback.exists()) return fallback.read();
    return _createKey(fallback);
  }

  Future<Uint8List> _migrateKey() async {
    final key = await migrationSource!.read();
    await _persistAndVerifyKey(storage, key);
    await migrationSource!.removeIfMatching(key);
    return key;
  }

  Future<Uint8List> _createKey(VaultKeyStorage destination) async {
    final key = generateRandomBytes(32);
    await _persistAndVerifyKey(destination, key);
    return key;
  }

  Future<void> _persistAndVerifyKey(
    VaultKeyStorage destination,
    Uint8List key,
  ) async {
    await destination.write(key);
    requireMatchingVaultKeys(key, await destination.read());
  }
}
