import 'package:flutter/services.dart';

import 'tpm_keys.dart';

final class MethodChannelTpmKeys implements TpmKeys {
  const MethodChannelTpmKeys();

  static const _channel = MethodChannel('hardware_keys');

  @override
  Future<bool> isAvailable() async =>
      (await _channel.invokeMethod<bool>('tpmIsAvailable'))!;

  @override
  Future<Uint8List> protect(Uint8List vaultKey) async =>
      (await _channel.invokeMethod<Uint8List>('tpmProtect', vaultKey))!;

  @override
  Future<Uint8List> unprotect(Uint8List protectedKey) async =>
      (await _channel.invokeMethod<Uint8List>('tpmUnprotect', protectedKey))!;
}
