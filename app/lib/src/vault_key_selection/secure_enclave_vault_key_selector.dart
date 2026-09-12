import 'dart:io';

import 'package:secure_keys/secure_enclave.dart';

import '../vault_key_files/recipient_key_handle_file.dart';
import '../vault_key_files/vault_key_envelope_file.dart';
import '../vault_key_files/tpm_protected_key_file.dart';
import '../vault_key_repository/plaintext_vault_key_repository.dart';
import '../vault_key_repository/secure_enclave_vault_key_repository.dart';
import '../vault_key_service.dart';
import 'plaintext_vault_key_selector.dart';
import 'vault_key_selector.dart';

final class SecureEnclaveVaultKeySelector implements VaultKeySelector {
  const SecureEnclaveVaultKeySelector(this.root, this.hardwareKeys);

  final Directory root;
  final SecureEnclaveKeys hardwareKeys;

  @override
  Future<VaultKeyService> select() async {
    if (await _hasProtectedKey()) {
      final recipient = await hardwareKeys.openRecipientKey(
        await RecipientKeyHandleFile(root).read(),
      );
      return _serviceFor(recipient);
    }
    if (!await _canCreateKey()) return PlaintextVaultKeySelector(root).select();
    return _serviceFor(await hardwareKeys.createRecipientKey());
  }

  Future<bool> _hasProtectedKey() async {
    if (await TpmProtectedKeyFile(root).exists()) {
      throw const FormatException('vault key is protected by another storage');
    }
    final hasHandle = await RecipientKeyHandleFile(root).exists();
    final hasEnvelope = await VaultKeyEnvelopeFile(root).exists();
    if (hasHandle != hasEnvelope) {
      throw const FormatException('incomplete hardware vault-key state');
    }
    return hasHandle;
  }

  Future<bool> _canCreateKey() async {
    final capabilities = await hardwareKeys.capabilities();
    return capabilities.available && capabilities.hardwareBacked;
  }

  VaultKeyService _serviceFor(RecipientKey recipient) =>
      VaultKeyService.protected(
        repository: SecureEnclaveVaultKeyRepository(root, recipient),
        encryptionKey: SecureEnclaveEncryptionKey(
          hardwareKeys,
          recipient.publicKey,
        ),
        decryptionKey: SecureEnclaveDecryptionKey(
          hardwareKeys,
          recipient.handle,
        ),
        migrationSource: PlaintextVaultKeyRepository(root),
      );
}
