import 'package:flutter/services.dart';

import '../hardware_key_backend.dart';
import '../key_capabilities.dart';
import '../recipient_key.dart';
import '../recipient_public_key.dart';
export '../recipient_key.dart';
export '../recipient_public_key.dart';

/// TPM implementation of [HardwareKeyBackend]. Generates a P-256 recipient key
/// and computes ECDH shared secrets; the envelope crypto lives in Dart.
final class TpmKeys implements HardwareKeyBackend {
  TpmKeys({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('secure_keys');

  final MethodChannel _channel;

  @override
  Future<KeyCapabilities> capabilities() async {
    final caps = (await _channel.invokeMapMethod<String, Object?>(
      'capabilities',
    ))!;
    final available = caps['available'] as bool && caps['hardwareBacked'] as bool;
    return KeyCapabilities(
      hardwareBacked: available,
      sharing: available,
      userPresence: false,
    );
  }

  @override
  Future<RecipientKey> createRecipientKey({
    required bool requireUserPresence,
  }) async {
    if (requireUserPresence) {
      throw UnsupportedError('TPM user presence is unsupported');
    }
    final result = (await _channel.invokeMapMethod<String, Object?>(
      'createRecipientKey',
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
    final result = (await _channel.invokeMapMethod<String, Object?>(
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
  }) async => (await _channel.invokeMethod<Uint8List>('sharedSecret', {
    'keyHandle': keyHandle,
    'peerPublicKey': peerPublicKey,
  }))!;
}
