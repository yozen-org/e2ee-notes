import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hardware_keys.dart';
import 'hardware_keys_platform_interface.dart';

// Dartとネイティブの間で、hardware_keysチャネルを通して引数と結果を変換する。
class MethodChannelHardwareKeys extends HardwareKeysPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('hardware_keys');

  @override
  Future<HardwareKeyCapabilities> capabilities() async =>
      HardwareKeyCapabilities.fromMap(
        (await methodChannel.invokeMapMethod<Object?, Object?>(
          'capabilities',
        ))!,
      );

  @override
  Future<RecipientKey> createRecipientKey({
    required bool requireUserPresence,
  }) async {
    final result = (await methodChannel.invokeMapMethod<Object?, Object?>(
      'createRecipientKey',
      {'requireUserPresence': requireUserPresence},
    ))!;
    return RecipientKey(
      handle: result['keyHandle']! as Uint8List,
      publicKey: RecipientPublicKey.fromMap(
        result['publicKey']! as Map<Object?, Object?>,
      ),
    );
  }

  @override
  Future<VaultKeyEnvelope> wrapVaultKey({
    required Uint8List vaultKey,
    required RecipientPublicKey recipient,
  }) async => VaultKeyEnvelope.fromMap(
    (await methodChannel.invokeMapMethod<Object?, Object?>('wrapVaultKey', {
      'vaultKey': vaultKey,
      'recipient': recipient.toMap(),
    }))!,
  );

  @override
  Future<Uint8List> unwrapVaultKey({
    required Uint8List keyHandle,
    required VaultKeyEnvelope envelope,
  }) async => (await methodChannel.invokeMethod<Uint8List>('unwrapVaultKey', {
    'keyHandle': keyHandle,
    'envelope': envelope.toMap(),
  }))!;
}
