import 'dart:typed_data';

import 'secure_enclave_keys_platform_interface.dart';

final class HardwareKeyCapabilities {
  const HardwareKeyCapabilities({
    required this.available,
    required this.hardwareBacked,
    required this.provider,
  });

  factory HardwareKeyCapabilities.fromMap(Map<Object?, Object?> map) =>
      HardwareKeyCapabilities(
        available: map['available'] as bool,
        hardwareBacked: map['hardwareBacked'] as bool,
        provider: map['provider'] as String,
      );

  final bool available;
  final bool hardwareBacked;
  final String provider;
}

final class RecipientPublicKey {
  const RecipientPublicKey({
    required this.version,
    required this.suite,
    required this.keyId,
    required this.publicKey,
  });

  factory RecipientPublicKey.fromMap(Map<Object?, Object?> map) =>
      RecipientPublicKey(
        version: map['version'] as int,
        suite: map['suite'] as String,
        keyId: map['keyID'] as String,
        publicKey: map['publicKey'] as String,
      );

  final int version;
  final String suite;
  final String keyId;
  final String publicKey;

  Map<String, Object> toMap() => {
    'version': version,
    'suite': suite,
    'keyID': keyId,
    'publicKey': publicKey,
  };
}

final class RecipientKey {
  const RecipientKey({required this.handle, required this.publicKey});
  final Uint8List handle;
  final RecipientPublicKey publicKey;
}

final class VaultKeyEnvelope {
  const VaultKeyEnvelope({
    required this.version,
    required this.suite,
    required this.recipientKeyId,
    required this.ephemeralPublicKey,
    required this.sealedKey,
  });

  factory VaultKeyEnvelope.fromMap(Map<Object?, Object?> map) =>
      VaultKeyEnvelope(
        version: map['version'] as int,
        suite: map['suite'] as String,
        recipientKeyId: map['recipientKeyID'] as String,
        ephemeralPublicKey: map['ephemeralPublicKey'] as String,
        sealedKey: map['sealedKey'] as String,
      );

  final int version;
  final String suite;
  final String recipientKeyId;
  final String ephemeralPublicKey;
  final String sealedKey;

  Map<String, Object> toMap() => {
    'version': version,
    'suite': suite,
    'recipientKeyID': recipientKeyId,
    'ephemeralPublicKey': ephemeralPublicKey,
    'sealedKey': sealedKey,
  };
}

class SecureEnclaveKeys {
  Future<HardwareKeyCapabilities> capabilities() =>
      SecureEnclaveKeysPlatform.instance.capabilities();

  Future<RecipientKey> createRecipientKey({bool requireUserPresence = false}) =>
      SecureEnclaveKeysPlatform.instance.createRecipientKey(
        requireUserPresence: requireUserPresence,
      );

  Future<VaultKeyEnvelope> wrapVaultKey({
    required Uint8List vaultKey,
    required RecipientPublicKey recipient,
  }) => SecureEnclaveKeysPlatform.instance.wrapVaultKey(
    vaultKey: vaultKey,
    recipient: recipient,
  );

  Future<Uint8List> unwrapVaultKey({
    required Uint8List keyHandle,
    required VaultKeyEnvelope envelope,
  }) => SecureEnclaveKeysPlatform.instance.unwrapVaultKey(
    keyHandle: keyHandle,
    envelope: envelope,
  );
}
