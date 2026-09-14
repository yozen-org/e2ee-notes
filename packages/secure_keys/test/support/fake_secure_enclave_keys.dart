import 'dart:convert';
import 'dart:typed_data';

import 'package:secure_keys/secure_enclave.dart';

final class FakeSecureEnclaveKeys extends SecureEnclaveKeys {
  FakeSecureEnclaveKeys({
    this.available = true,
    this.hardwareBacked = true,
    this.corruptUnwrappedKey = false,
    this.beforeWrap,
  });

  int generatedKeys = 0;
  bool requestedUserPresence = false;
  int capabilityChecks = 0;
  static const publicKey = RecipientPublicKey(
    version: 1,
    suite: 'test-suite',
    keyId: 'test-key',
    publicKey: 'test-public',
  );

  final bool corruptUnwrappedKey;
  bool available;
  bool hardwareBacked;
  final Future<void> Function()? beforeWrap;

  @override
  Future<HardwareKeyCapabilities> capabilities() async {
    capabilityChecks++;
    return HardwareKeyCapabilities(
      available: available,
      hardwareBacked: hardwareBacked,
      provider: 'Test hardware',
    );
  }

  @override
  Future<RecipientKey> createRecipientKey({
    bool requireUserPresence = false,
  }) async {
    generatedKeys++;
    requestedUserPresence = requireUserPresence;
    return RecipientKey(
      handle: Uint8List.fromList([1, 2, 3]),
      publicKey: publicKey,
    );
  }

  @override
  Future<RecipientKey> openRecipientKey(Uint8List keyHandle) async {
    if (!available || !hardwareBacked) throw StateError('Hardware unavailable');
    return RecipientKey(handle: keyHandle, publicKey: publicKey);
  }

  @override
  Future<VaultKeyEnvelope> wrapVaultKey({
    required Uint8List vaultKey,
    required RecipientPublicKey recipient,
  }) async {
    await beforeWrap?.call();
    return VaultKeyEnvelope(
      version: 1,
      suite: recipient.suite,
      recipientKeyId: recipient.keyId,
      ephemeralPublicKey: 'test-ephemeral',
      sealedKey: base64Encode(vaultKey),
    );
  }

  @override
  Future<Uint8List> unwrapVaultKey({
    required Uint8List keyHandle,
    required VaultKeyEnvelope envelope,
  }) async {
    if (!available || !hardwareBacked) throw StateError('Hardware unavailable');
    final key = base64Decode(envelope.sealedKey);
    if (corruptUnwrappedKey) key[0] ^= 1;
    return key;
  }
}
