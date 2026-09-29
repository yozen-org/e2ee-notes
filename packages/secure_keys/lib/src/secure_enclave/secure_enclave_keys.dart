import '../hardware_key_backend.dart';
import '../key_capabilities.dart';
import '../recipient_key.dart';
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

final class SecureEnclaveKeys implements HardwareKeyBackend {
  @override
  Future<KeyCapabilities> capabilities() async {
    final caps = await SecureEnclaveKeysPlatform.instance.capabilities();
    final available = caps.available && caps.hardwareBacked;
    return KeyCapabilities(
      hardwareBacked: available,
      sharing: available,
      userPresence: available,
    );
  }

  @override
  Future<RecipientKey> createRecipientKey({bool requireUserPresence = false}) =>
      SecureEnclaveKeysPlatform.instance.createRecipientKey(
        requireUserPresence: requireUserPresence,
      );

  @override
  Future<RecipientKey> openRecipientKey(Uint8List keyHandle) =>
      SecureEnclaveKeysPlatform.instance.openRecipientKey(keyHandle);

  @override
  Future<Uint8List> sharedSecret({
    required Uint8List keyHandle,
    required Uint8List peerPublicKey,
  }) => SecureEnclaveKeysPlatform.instance.sharedSecret(
    keyHandle: keyHandle,
    peerPublicKey: peerPublicKey,
  );
}
