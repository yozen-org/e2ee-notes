import 'dart:io';
import 'dart:typed_data';

import 'package:secure_keys/tpm.dart';

import '../vault_key_files/recipient_key_handle_file.dart';
import '../vault_key_files/tpm_protected_key_file.dart';
import '../vault_key_files/vault_key_envelope_file.dart';
import '../vault_key_validation.dart';
import 'vault_key_storage.dart';

final class TpmVaultKeyStorage implements VaultKeyStorage {
  TpmVaultKeyStorage(this.root, this.tpmKeys);

  final Directory root;
  final TpmKeys tpmKeys;

  @override
  Future<bool> exists() async {
    if (await RecipientKeyHandleFile(root).exists() ||
        await VaultKeyEnvelopeFile(root).exists()) {
      throw const FormatException('vault key is protected by another storage');
    }
    return TpmProtectedKeyFile(root).exists();
  }

  @override
  Future<bool> isAvailable() => tpmKeys.isAvailable();

  @override
  Future<Uint8List> read() async {
    final key = await tpmKeys.unprotect(await TpmProtectedKeyFile(root).read());
    validateVaultKey(key);
    return key;
  }

  @override
  Future<void> write(Uint8List key) async {
    validateVaultKey(key);
    final protectedKey = await tpmKeys.protect(key);
    requireMatchingVaultKeys(key, await tpmKeys.unprotect(protectedKey));
    await TpmProtectedKeyFile(root).write(protectedKey);
  }
}
