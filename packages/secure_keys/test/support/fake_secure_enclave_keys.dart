import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:secure_keys/src/hardware_key_backend.dart';
import 'package:secure_keys/src/key_capabilities.dart';
import 'package:secure_keys/src/recipient_key.dart';
import 'package:secure_keys/src/recipient_public_key.dart';

/// An in-memory P-256 backend that performs real ECDH, standing in for the
/// platform hardware key store in tests.
final class FakeSecureEnclaveKeys implements HardwareKeyBackend {
  FakeSecureEnclaveKeys({this.available = true});

  bool available;
  int generatedKeys = 0;
  bool requestedUserPresence = false;

  final ECDomainParameters _curve = ECDomainParameters('secp256r1');
  final Random _random = Random.secure();
  final Map<int, ECPrivateKey> _keys = {};

  @override
  Future<KeyCapabilities> capabilities() async => KeyCapabilities(
    hardwareBacked: available,
    sharing: available,
    userPresence: available,
  );

  @override
  Future<RecipientKey> createRecipientKey({
    required bool requireUserPresence,
  }) async {
    generatedKeys++;
    requestedUserPresence = requireUserPresence;
    final private = ECPrivateKey(_randomScalar(), _curve);
    _keys[generatedKeys] = private;
    return RecipientKey(
      handle: Uint8List.fromList([generatedKeys]),
      publicKey: _publicKey(private),
    );
  }

  @override
  Future<RecipientKey> openRecipientKey(Uint8List keyHandle) async {
    final private = _keys[keyHandle.first];
    if (private == null) throw StateError('unknown key handle');
    return RecipientKey(handle: keyHandle, publicKey: _publicKey(private));
  }

  @override
  Future<Uint8List> sharedSecret({
    required Uint8List keyHandle,
    required Uint8List peerPublicKey,
  }) async {
    final private = _keys[keyHandle.first];
    if (private == null) throw StateError('unknown key handle');
    final agreement = ECDHBasicAgreement()..init(private);
    final peerPoint = _curve.curve.decodePoint(peerPublicKey);
    if (peerPoint == null || peerPoint.isInfinity) {
      throw const FormatException('invalid peer public key');
    }
    return _bigIntToFixed(
      agreement.calculateAgreement(ECPublicKey(peerPoint, _curve)),
      32,
    );
  }

  RecipientPublicKey _publicKey(ECPrivateKey private) {
    final encoded = (_curve.G * private.d!)!.getEncoded(false);
    return RecipientPublicKey(
      version: 1,
      suite: 'P256-HKDF-SHA256-AES256GCM',
      keyId: _keyId(encoded),
      publicKey: base64Encode(encoded),
    );
  }

  String _keyId(Uint8List publicKey) => SHA256Digest()
      .process(publicKey)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();

  BigInt _randomScalar() {
    final order = _curve.n;
    BigInt candidate;
    do {
      candidate = _bytesToBigInt(
        Uint8List.fromList(List.generate(32, (_) => _random.nextInt(256))),
      );
    } while (candidate == BigInt.zero || candidate >= order);
    return candidate;
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value;
  }

  static Uint8List _bigIntToFixed(BigInt value, int length) {
    final result = Uint8List(length);
    var remaining = value;
    for (var index = length - 1; index >= 0; index--) {
      result[index] = (remaining & BigInt.from(0xff)).toInt();
      remaining >>= 8;
    }
    return result;
  }
}
