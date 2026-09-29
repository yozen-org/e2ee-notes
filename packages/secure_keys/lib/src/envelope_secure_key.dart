import 'dart:convert';
import 'dart:typed_data';

import 'generated_key.dart';
import 'hardware_key_backend.dart';
import 'key_capabilities.dart';
import 'key_envelope_cipher.dart';
import 'key_policy.dart';
import 'key_record.dart';
import 'recipient_key.dart';
import 'recipient_public_key.dart';
import 'secure_key.dart';
import 'vault_key_envelope.dart';
import 'vault_key_validation.dart';

/// Hardware-independent vault-key lifecycle backed by a [HardwareKeyBackend].
///
/// The envelope wrapping/unwrapping is done by a [KeyEnvelopeCipher] in Dart;
/// the backend only manages the P-256 recipient key and computes shared
/// secrets with it. Every hardware platform (Secure Enclave, Keystore, TPM)
/// uses this same class with its own backend.
final class EnvelopeSecureKey extends SecureKey {
  EnvelopeSecureKey({
    required this.backend,
    required this.provider,
    KeyEnvelopeCipher? cipher,
  }) : _cipher = cipher ?? KeyEnvelopeCipher();

  final HardwareKeyBackend backend;
  final String provider;
  final KeyEnvelopeCipher _cipher;

  @override
  Future<KeyCapabilities> capabilities() => backend.capabilities();

  @override
  Future<GeneratedKey> protect(
    Uint8List vaultKey, {
    required KeyPolicy policy,
  }) async {
    validateVaultKey(vaultKey);
    await _requireSupported(policy);
    final recipient = await backend.createRecipientKey(
      requireUserPresence: policy.requireUserPresence,
    );
    final envelope = await _cipher.wrap(
      vaultKey: vaultKey,
      recipient: recipient.publicKey,
    );
    final record = _record(recipient.handle, envelope);
    requireMatchingVaultKeys(vaultKey, await open(record));
    return GeneratedKey(vaultKey, record);
  }

  @override
  Future<Uint8List> open(KeyRecord record) async {
    final (handle, envelope) = _payload(record);
    final recipient = await backend.openRecipientKey(handle);
    _requireOwn(recipient.publicKey, envelope);
    final shared = await backend.sharedSecret(
      keyHandle: handle,
      peerPublicKey: base64Decode(envelope.ephemeralPublicKey),
    );
    final key = await _cipher.unwrap(sharedSecret: shared, envelope: envelope);
    validateVaultKey(key);
    return key;
  }

  @override
  Future<RecipientKey> createRecipientKey({required KeyPolicy policy}) async {
    await _requireSupported(policy);
    return backend.createRecipientKey(
      requireUserPresence: policy.requireUserPresence,
    );
  }

  @override
  Future<RecipientPublicKey> publicKey(KeyRecord record) async =>
      (await backend.openRecipientKey(_handle(record))).publicKey;

  @override
  Future<VaultKeyEnvelope> envelope(
    Uint8List vaultKey,
    RecipientPublicKey recipient,
  ) {
    validateVaultKey(vaultKey);
    return _cipher.wrap(vaultKey: vaultKey, recipient: recipient);
  }

  @override
  Future<GeneratedKey> accept(
    VaultKeyEnvelope envelope,
    RecipientKey recipient, {
    required KeyPolicy policy,
  }) async {
    final handle = recipient.handle;
    final own = await backend.openRecipientKey(handle);
    _requireOwn(own.publicKey, envelope);
    final shared = await backend.sharedSecret(
      keyHandle: handle,
      peerPublicKey: base64Decode(envelope.ephemeralPublicKey),
    );
    final key = await _cipher.unwrap(sharedSecret: shared, envelope: envelope);
    return protect(key, policy: policy);
  }

  KeyRecord _record(Uint8List handle, VaultKeyEnvelope envelope) => KeyRecord(
    provider,
    {'handle': base64Encode(handle), 'envelope': envelope.toMap()},
  );

  (Uint8List, VaultKeyEnvelope) _payload(KeyRecord record) {
    final handle = _handle(record);
    final envelope = VaultKeyEnvelope.fromMap(
      record.data['envelope'] as Map<String, dynamic>,
    );
    return (handle, envelope);
  }

  Uint8List _handle(KeyRecord record) {
    if (record.provider != provider) {
      throw const FormatException('Unexpected key provider');
    }
    return base64Decode(record.data['handle'] as String);
  }

  void _requireOwn(RecipientPublicKey own, VaultKeyEnvelope envelope) {
    if (own.keyId != envelope.recipientKeyId) {
      throw const FormatException('envelope was not wrapped for this key');
    }
  }

  Future<void> _requireSupported(KeyPolicy policy) async {
    if (policy.requireUserPresence &&
        !(await backend.capabilities()).userPresence) {
      throw UnsupportedError('User presence is unsupported');
    }
  }
}
