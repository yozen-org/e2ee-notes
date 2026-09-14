import 'dart:io';

import 'package:secure_keys/tpm.dart';

import '../vault_key_files/recipient_key_handle_file.dart';
import '../vault_key_files/vault_key_envelope_file.dart';
import '../vault_key_repository/plaintext_vault_key_repository.dart';
import '../vault_key_repository/tpm_vault_key_repository.dart';
import '../vault_key_service.dart';
import 'plaintext_vault_key_selector.dart';
import 'vault_key_selector.dart';

final class TpmVaultKeySelector implements VaultKeySelector {
  const TpmVaultKeySelector(this.root, this.tpmKeys);

  final Directory root;
  final TpmKeys tpmKeys;

  @override
  Future<VaultKeyService> select() async {
    await _rejectForeignKey();
    final repository = TpmVaultKeyRepository(root);
    if (await repository.exists() || await tpmKeys.isAvailable()) {
      return VaultKeyService.protected(
        repository: repository,
        encryptionKey: TpmEncryptionKey(tpmKeys),
        decryptionKey: TpmDecryptionKey(tpmKeys),
        migrationSource: PlaintextVaultKeyRepository(root),
      );
    }
    return PlaintextVaultKeySelector(root).select();
  }

  Future<void> _rejectForeignKey() async {
    if (await RecipientKeyHandleFile(root).exists() ||
        await VaultKeyEnvelopeFile(root).exists()) {
      throw const FormatException('vault key is protected by another storage');
    }
  }
}
