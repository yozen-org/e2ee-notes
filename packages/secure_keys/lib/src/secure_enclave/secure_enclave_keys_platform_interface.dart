import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'secure_enclave_keys.dart';
import 'secure_enclave_keys_method_channel.dart';

abstract class SecureEnclaveKeysPlatform extends PlatformInterface {
  SecureEnclaveKeysPlatform() : super(token: _token);

  static final Object _token = Object();

  static SecureEnclaveKeysPlatform _instance = MethodChannelSecureEnclaveKeys();

  static SecureEnclaveKeysPlatform get instance => _instance;

  static set instance(SecureEnclaveKeysPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<HardwareKeyCapabilities> capabilities();

  Future<RecipientKey> createRecipientKey({required bool requireUserPresence});

  Future<RecipientKey> openRecipientKey(Uint8List keyHandle);

  Future<VaultKeyEnvelope> wrapVaultKey({
    required Uint8List vaultKey,
    required RecipientPublicKey recipient,
  });

  Future<Uint8List> unwrapVaultKey({
    required Uint8List keyHandle,
    required VaultKeyEnvelope envelope,
  });
}
