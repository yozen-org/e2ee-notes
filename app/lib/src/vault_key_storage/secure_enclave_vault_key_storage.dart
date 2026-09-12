import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:secure_keys/secure_enclave.dart';
import 'package:path/path.dart' as p;

import '../vault_key_files/recipient_key_handle_file.dart';
import '../vault_key_files/tpm_protected_key_file.dart';
import '../vault_key_files/vault_key_envelope_file.dart';
import '../vault_key_validation.dart';
import 'vault_key_storage.dart';

final class SecureEnclaveVaultKeyStorage implements VaultKeyStorage {
  SecureEnclaveVaultKeyStorage(this.root, this.hardwareKeys);

  final Directory root;
  final SecureEnclaveKeys hardwareKeys;

  @override
  Future<bool> exists() async {
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

  @override
  Future<bool> isAvailable() async {
    final capabilities = await hardwareKeys.capabilities();
    return capabilities.available && capabilities.hardwareBacked;
  }

  @override
  Future<Uint8List> read() async {
    final key = await hardwareKeys.unwrapVaultKey(
      keyHandle: await RecipientKeyHandleFile(root).read(),
      envelope: await VaultKeyEnvelopeFile(root).read(),
    );
    validateVaultKey(key);
    return key;
  }

  @override
  Future<void> write(Uint8List key) async {
    validateVaultKey(key);
    final recipient = await hardwareKeys.createRecipientKey();
    final envelope = await _wrapAndVerifyKey(key, recipient);
    await _persistProtectedKey(recipient, envelope);
  }

  Future<VaultKeyEnvelope> _wrapAndVerifyKey(
    Uint8List key,
    RecipientKey recipient,
  ) async {
    final envelope = await hardwareKeys.wrapVaultKey(
      vaultKey: key,
      recipient: recipient.publicKey,
    );
    final restored = await hardwareKeys.unwrapVaultKey(
      keyHandle: recipient.handle,
      envelope: envelope,
    );
    requireMatchingVaultKeys(key, restored);
    return envelope;
  }

  Future<void> _persistProtectedKey(
    RecipientKey recipient,
    VaultKeyEnvelope envelope,
  ) async {
    await RecipientKeyHandleFile(root).write(recipient.handle);
    await VaultKeyEnvelopeFile(root).write(envelope);
    await File(p.join(root.path, 'recipient-public.json'))
        .writeAsString(jsonEncode(recipient.publicKey.toMap()), flush: true);
  }
}
