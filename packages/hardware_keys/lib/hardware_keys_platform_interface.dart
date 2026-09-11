import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hardware_keys.dart';
import 'hardware_keys_method_channel.dart';

// OS別の実装やテスト用の代替実装を差し替えるための共通インターフェース。
abstract class HardwareKeysPlatform extends PlatformInterface {
  /// 実装の差し替えを検証するトークンを初期化する。
  HardwareKeysPlatform() : super(token: _token);

  static final Object _token = Object();

  static HardwareKeysPlatform _instance = MethodChannelHardwareKeys();

  /// 現在利用するプラットフォーム実装。
  ///
  /// 既定では[MethodChannelHardwareKeys]を使用する。
  static HardwareKeysPlatform get instance => _instance;

  /// OS別の実装を登録するときに、[HardwareKeysPlatform]の派生クラスを設定する。
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
