import 'dart:io';
import 'dart:typed_data';

import 'package:hardware_keys/tpm_keys.dart';
import 'package:path/path.dart' as p;

import '../generate_random_bytes.dart';
import '../vault_key_files/recipient_key_handle_file.dart';
import '../vault_key_files/tpm_protected_key_file.dart';
import '../vault_key_files/vault_key_envelope_file.dart';
import 'software_vault_key_provider.dart';
import 'vault_key_provider.dart';

final class TpmVaultKeyProvider implements VaultKeyProvider {
  TpmVaultKeyProvider(this.tpmKeys);

  final TpmKeys tpmKeys;

  @override
  Future<Uint8List> openKey(Directory root) async {
    if (await TpmProtectedKeyFile(root).exists()) {
      return _restoreKey(root);
    }
    await _rejectForeignProtectedKey(root);
    if (!await tpmKeys.isAvailable()) {
      return const SoftwareVaultKeyProvider().openKey(root);
    }
    return _migrateOrCreateKey(root);
  }

  Future<void> _rejectForeignProtectedKey(Directory root) async {
    if (await RecipientKeyHandleFile(root).exists() ||
        await VaultKeyEnvelopeFile(root).exists()) {
      throw const FormatException('vault key is protected by another provider');
    }
  }

  Future<Uint8List> _migrateOrCreateKey(Directory root) async {
    final softwareKey = File(p.join(root.path, 'vault-key.bin'));
    if (await softwareKey.exists()) {
      return _migrateSoftwareKey(root, softwareKey);
    }
    return _createProtectedKey(root);
  }

  Future<Uint8List> _restoreKey(Directory root) async {
    final protectedKey = await TpmProtectedKeyFile(root).read();
    final vaultKey = await tpmKeys.unprotect(protectedKey);
    _validateKeyLength(vaultKey);
    await _removeMatchingSoftwareKey(root, vaultKey);
    return vaultKey;
  }

  Future<Uint8List> _migrateSoftwareKey(
    Directory root,
    File softwareKey,
  ) async {
    final vaultKey = await softwareKey.readAsBytes();
    _validateKeyLength(vaultKey);
    await _protectAndPersistKey(root, vaultKey);
    await _removeMatchingSoftwareKey(root, vaultKey);
    return vaultKey;
  }

  Future<Uint8List> _createProtectedKey(Directory root) async {
    final vaultKey = generateRandomBytes(32);
    await _protectAndPersistKey(root, vaultKey);
    return vaultKey;
  }

  Future<void> _protectAndPersistKey(Directory root, Uint8List vaultKey) async {
    final protectedKey = await tpmKeys.protect(vaultKey);
    final restored = await tpmKeys.unprotect(protectedKey);
    if (!_sameKey(vaultKey, restored)) {
      throw const FormatException('TPM vault-key verification failed');
    }
    await TpmProtectedKeyFile(root).write(protectedKey);
  }

  Future<void> _removeMatchingSoftwareKey(
    Directory root,
    Uint8List vaultKey,
  ) async {
    final softwareKey = File(p.join(root.path, 'vault-key.bin'));
    if (!await softwareKey.exists()) return;
    if (!_sameKey(vaultKey, await softwareKey.readAsBytes())) {
      throw const FormatException('TPM and software vault keys differ');
    }
    await softwareKey.delete();
  }

  static void _validateKeyLength(Uint8List key) {
    if (key.length != 32) {
      throw const FormatException('invalid vault-key length');
    }
  }

  static bool _sameKey(Uint8List left, Uint8List right) {
    if (left.length != 32 || right.length != 32) return false;
    var difference = 0;
    for (var index = 0; index < 32; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}
