import '../recipient_public_key.dart';
import '../recipient_key.dart';
import '../vault_key_envelope.dart';
export '../recipient_public_key.dart';
export '../recipient_key.dart';
export '../vault_key_envelope.dart';

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

class SecureEnclaveKeys {
  Future<HardwareKeyCapabilities> capabilities() =>
      SecureEnclaveKeysPlatform.instance.capabilities();

  Future<RecipientKey> createRecipientKey({bool requireUserPresence = false}) =>
      SecureEnclaveKeysPlatform.instance.createRecipientKey(
        requireUserPresence: requireUserPresence,
      );

  Future<RecipientKey> openRecipientKey(Uint8List keyHandle) =>
      SecureEnclaveKeysPlatform.instance.openRecipientKey(keyHandle);

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
