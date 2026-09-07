import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hardware_keys.dart';
import 'hardware_keys_method_channel.dart';

abstract class HardwareKeysPlatform extends PlatformInterface {
  /// Constructs a HardwareKeysPlatform.
  HardwareKeysPlatform() : super(token: _token);

  static final Object _token = Object();

  static HardwareKeysPlatform _instance = MethodChannelHardwareKeys();

  /// The default instance of [HardwareKeysPlatform] to use.
  ///
  /// Defaults to [MethodChannelHardwareKeys].
  static HardwareKeysPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HardwareKeysPlatform] when
  /// they register themselves.
  static set instance(HardwareKeysPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<HardwareKeyCapabilities> capabilities();

  Future<RecipientKey> createRecipientKey({required bool requireUserPresence});

  Future<VaultKeyEnvelope> wrapVaultKey({
    required Uint8List vaultKey,
    required RecipientPublicKey recipient,
  });

  Future<Uint8List> unwrapVaultKey({
    required Uint8List keyHandle,
    required VaultKeyEnvelope envelope,
  });
}
