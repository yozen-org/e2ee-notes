import 'package:flutter/services.dart';

import 'android_keystore_keys.dart';

final class MethodChannelAndroidKeystoreKeys implements AndroidKeystoreKeys {
  const MethodChannelAndroidKeystoreKeys();

  static const _channel = MethodChannel('secure_keys');

  @override
  Future<bool> isAvailable() async =>
      (await _channel.invokeMethod<bool>('keystoreIsAvailable'))!;

  @override
  Future<ProtectedVaultKey> protect(Uint8List vaultKey) async {
    final result = (await _channel.invokeMapMethod<String, Object?>(
      'keystoreProtect',
      vaultKey,
    ))!;
    return ProtectedVaultKey(
      alias: result['alias']! as String,
      iv: result['iv']! as Uint8List,
      ciphertext: result['ciphertext']! as Uint8List,
    );
  }

  @override
  Future<Uint8List> unprotect(ProtectedVaultKey protected) async =>
      (await _channel.invokeMethod<Uint8List>('keystoreUnprotect', {
        'alias': protected.alias,
        'iv': protected.iv,
        'ciphertext': protected.ciphertext,
      }))!;
}
