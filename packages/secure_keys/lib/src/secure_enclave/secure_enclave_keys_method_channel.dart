import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'secure_enclave_keys.dart';
import 'secure_enclave_keys_platform_interface.dart';

class MethodChannelSecureEnclaveKeys extends SecureEnclaveKeysPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('secure_keys');

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
  Future<RecipientKey> openRecipientKey(Uint8List keyHandle) async {
    final result = (await methodChannel.invokeMapMethod<Object?, Object?>(
      'openRecipientKey',
      {'keyHandle': keyHandle},
    ))!;
    return RecipientKey(
      handle: keyHandle,
      publicKey: RecipientPublicKey.fromMap(result),
    );
  }

  @override
  Future<Uint8List> sharedSecret({
    required Uint8List keyHandle,
    required Uint8List peerPublicKey,
  }) async => (await methodChannel.invokeMethod<Uint8List>('sharedSecret', {
    'keyHandle': keyHandle,
    'peerPublicKey': peerPublicKey,
  }))!;
}
