import 'dart:io';

import '../vault_key_files/recipient_key_handle_file.dart';
import '../vault_key_files/vault_key_envelope_file.dart';
import '../vault_key_files/tpm_protected_key_file.dart';
import '../vault_key_repository/plaintext_vault_key_repository.dart';
import '../vault_key_service.dart';
import 'vault_key_selector.dart';

final class PlaintextVaultKeySelector implements VaultKeySelector {
  const PlaintextVaultKeySelector(this.root);

  final Directory root;

  @override
  Future<VaultKeyService> select() async {
    if (await RecipientKeyHandleFile(root).exists() ||
        await VaultKeyEnvelopeFile(root).exists() ||
        await TpmProtectedKeyFile(root).exists()) {
      throw const FormatException('vault key is protected by another storage');
    }
    return VaultKeyService.plaintext(
      repository: PlaintextVaultKeyRepository(root),
    );
  }
}
