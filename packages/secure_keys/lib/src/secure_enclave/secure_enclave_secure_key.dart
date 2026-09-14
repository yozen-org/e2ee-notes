import 'dart:convert';
import 'dart:typed_data';

import '../generated_key.dart';
import '../key_capabilities.dart';
import '../key_policy.dart';
import '../key_record.dart';
import '../secure_key.dart';
import '../vault_key_validation.dart';
import 'secure_enclave_keys.dart';

final class SecureEnclaveSecureKey extends SecureKey {
  SecureEnclaveSecureKey(this.keys);
  final SecureEnclaveKeys keys;

  @override
  Future<KeyCapabilities> capabilities() async {
    final caps = await keys.capabilities();
    final available = caps.available && caps.hardwareBacked;
    return KeyCapabilities(
      hardwareBacked: available,
      sharing: available,
      userPresence: available,
    );
  }

  @override
  Future<GeneratedKey> protect(
    Uint8List vaultKey, {
    required KeyPolicy policy,
  }) async {
    validateVaultKey(vaultKey);
    final recipient = await keys.createRecipientKey(
      requireUserPresence: policy.requireUserPresence,
    );
    return _protectFor(vaultKey, recipient);
  }

  Future<GeneratedKey> _protectFor(
    Uint8List key,
    RecipientKey recipient,
  ) async {
    final wrapped = await envelope(key, recipient.publicKey);
    final record = KeyRecord('secure-enclave', {
      'handle': base64Encode(recipient.handle),
      'envelope': wrapped.toMap(),
    });
    requireMatchingVaultKeys(key, await open(record));
    return GeneratedKey(key, record);
  }

  Future<RecipientKey> _recipient(KeyRecord record) {
    if (record.provider != 'secure-enclave') {
      throw const FormatException('Unexpected key provider');
    }
    return keys.openRecipientKey(base64Decode(record.data['handle'] as String));
  }

  @override
  Future<Uint8List> open(KeyRecord record) async {
    final recipient = await _recipient(record);
    final wrapped = VaultKeyEnvelope.fromMap(
      record.data['envelope'] as Map<String, dynamic>,
    );
    final key = await keys.unwrapVaultKey(
      keyHandle: recipient.handle,
      envelope: wrapped,
    );
    validateVaultKey(key);
    return key;
  }

  @override
  Future<RecipientPublicKey> publicKey(KeyRecord record) async =>
      (await _recipient(record)).publicKey;

  @override
  Future<VaultKeyEnvelope> envelope(
    Uint8List vaultKey,
    RecipientPublicKey recipient,
  ) {
    validateVaultKey(vaultKey);
    return keys.wrapVaultKey(vaultKey: vaultKey, recipient: recipient);
  }

  @override
  Future<GeneratedKey> accept(
    VaultKeyEnvelope envelope,
    KeyRecord recipient, {
    required KeyPolicy policy,
  }) async {
    final own = await _recipient(recipient);
    final key = await keys.unwrapVaultKey(
      keyHandle: own.handle,
      envelope: envelope,
    );
    validateVaultKey(key);
    return protect(key, policy: policy);
  }
}
