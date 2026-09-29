import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'recipient_public_key.dart';
import 'vault_key_envelope.dart';

/// Wraps and unwraps a 32-byte vault key using the P-256 envelope protocol in
/// [KEY_ENVELOPE_V1.md](../../../../spec/KEY_ENVELOPE_V1.md).
///
/// The shared secret for [unwrap] is produced by the platform's hardware key
/// (Secure Enclave / Keystore / TPM). Only the wrapping crypto lives here.
final class KeyEnvelopeCipher {
  KeyEnvelopeCipher({Random? random}) : _random = random ?? Random.secure();

  static const suite = 'P256-HKDF-SHA256-AES256GCM';
  static const _hkdfInfo = 'yozen.e2ee-notes.key-wrap.v1';
  static const _keyLength = 32;
  static const _nonceLength = 12;

  final Random _random;
  final ECDomainParameters _curve = ECDomainParameters('secp256r1');

  Future<VaultKeyEnvelope> wrap({
    required Uint8List vaultKey,
    required RecipientPublicKey recipient,
    Uint8List? ephemeralPrivateKey,
    Uint8List? nonce,
  }) async {
    _validateVaultKey(vaultKey);
    final recipientPublic = _parseRecipient(recipient);
    final ephemeral = _ephemeralKey(ephemeralPrivateKey);
    return _wrap(
      vaultKey: vaultKey,
      recipientKeyId: recipient.keyId,
      recipientPublic: recipientPublic,
      ephemeral: ephemeral,
      nonce: nonce ?? _newNonce(),
    );
  }

  Future<Uint8List> unwrap({
    required Uint8List sharedSecret,
    required VaultKeyEnvelope envelope,
  }) async {
    _validateSharedSecret(sharedSecret);
    final wrappingKey = _deriveWrappingKey(
      sharedSecret,
      envelope.recipientKeyId,
    );
    return _aesOpen(
      sealedKey: base64Decode(envelope.sealedKey),
      wrappingKey: wrappingKey,
      keyId: envelope.recipientKeyId,
    );
  }

  VaultKeyEnvelope _wrap({
    required Uint8List vaultKey,
    required String recipientKeyId,
    required ECPublicKey recipientPublic,
    required ECPrivateKey ephemeral,
    required Uint8List nonce,
  }) {
    final ephemeralPublic = ephemeral.parameters!.G * ephemeral.d!;
    final sharedSecret = _sharedSecret(ephemeral, recipientPublic);
    final wrappingKey = _deriveWrappingKey(sharedSecret, recipientKeyId);
    final sealedKey = _aesSeal(
      vaultKey: vaultKey,
      wrappingKey: wrappingKey,
      nonce: nonce,
      keyId: recipientKeyId,
    );
    return VaultKeyEnvelope(
      version: 1,
      suite: suite,
      recipientKeyId: recipientKeyId,
      ephemeralPublicKey: base64Encode(ephemeralPublic!.getEncoded(false)),
      sealedKey: base64Encode(sealedKey),
    );
  }

  ECPublicKey _parseRecipient(RecipientPublicKey recipient) {
    if (recipient.version != 1 || recipient.suite != suite) {
      throw const FormatException('unsupported recipient public key');
    }
    final encoded = base64Decode(recipient.publicKey);
    if (_keyId(encoded) != recipient.keyId) {
      throw const FormatException('recipient key id mismatch');
    }
    final point = _curve.curve.decodePoint(encoded);
    if (point == null || point.isInfinity) {
      throw const FormatException('invalid recipient public key');
    }
    return ECPublicKey(point, _curve);
  }

  ECPrivateKey _ephemeralKey(Uint8List? scalar) {
    if (scalar != null) {
      if (scalar.length != _keyLength) {
        throw const FormatException('invalid ephemeral key length');
      }
      return ECPrivateKey(_bytesToBigInt(scalar), _curve);
    }
    return ECPrivateKey(_randomScalar(), _curve);
  }

  BigInt _randomScalar() {
    final order = _curve.n;
    BigInt candidate;
    do {
      candidate = _bytesToBigInt(
        Uint8List.fromList(
          List.generate(_keyLength, (_) => _random.nextInt(256)),
        ),
      );
    } while (candidate == BigInt.zero || candidate >= order);
    return candidate;
  }

  Uint8List _sharedSecret(ECPrivateKey private, ECPublicKey public) {
    final agreement = ECDHBasicAgreement()..init(private);
    return _bigIntToFixed(agreement.calculateAgreement(public), _keyLength);
  }

  Uint8List _deriveWrappingKey(Uint8List sharedSecret, String keyId) {
    final kdf = HKDFKeyDerivator(SHA256Digest())
      ..init(
        HkdfParameters(
          sharedSecret,
          _keyLength,
          utf8.encode(keyId),
          utf8.encode(_hkdfInfo),
        ),
      );
    return kdf.process(Uint8List(0));
  }

  Uint8List _aesSeal({
    required Uint8List vaultKey,
    required Uint8List wrappingKey,
    required Uint8List nonce,
    required String keyId,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(wrappingKey), 128, nonce, _aad(keyId)),
      );
    final ciphertextAndTag = cipher.process(vaultKey);
    return Uint8List.fromList([...nonce, ...ciphertextAndTag]);
  }

  Uint8List _aesOpen({
    required Uint8List sealedKey,
    required Uint8List wrappingKey,
    required String keyId,
  }) {
    if (sealedKey.length <= _nonceLength) {
      throw const FormatException('invalid sealed key');
    }
    final nonce = sealedKey.sublist(0, _nonceLength);
    final ciphertextAndTag = sealedKey.sublist(_nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(wrappingKey), 128, nonce, _aad(keyId)),
      );
    final vaultKey = cipher.process(ciphertextAndTag);
    _validateVaultKey(vaultKey);
    return vaultKey;
  }

  Uint8List _aad(String keyId) => utf8.encode('$suite:$keyId');

  String _keyId(Uint8List publicKey) =>
      SHA256Digest().process(publicKey).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  Uint8List _newNonce() =>
      Uint8List.fromList(List.generate(_nonceLength, (_) => _random.nextInt(256)));

  static void _validateVaultKey(Uint8List key) {
    if (key.length != _keyLength) {
      throw const FormatException('invalid vault-key length');
    }
  }

  static void _validateSharedSecret(Uint8List sharedSecret) {
    if (sharedSecret.length != _keyLength) {
      throw const FormatException('invalid shared-secret length');
    }
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
