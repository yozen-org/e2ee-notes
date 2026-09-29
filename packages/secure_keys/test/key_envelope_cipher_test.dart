import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/src/key_envelope_cipher.dart';
import 'package:secure_keys/src/recipient_public_key.dart';
import 'package:secure_keys/src/vault_key_envelope.dart';

const _recipient = RecipientPublicKey(
  version: 1,
  suite: 'P256-HKDF-SHA256-AES256GCM',
  keyId: '9e396cb4f62b15eb7e31cb20fcd9927239cda600ae6e92175c871e6a495a5e16',
  publicKey:
      'BIfIHcCB7b7C5x3L/pON4S38KJMJJgNjN8hSV/BFO0uHdWnKTq+zMm2j3s6GoM+x4fTYqltEk+BiC5ZDghZdaN4=',
);

const _vaultKeyHex =
    '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';

void main() {
  test('wrap matches the Swift-generated conformance vector', () async {
    final cipher = KeyEnvelopeCipher();

    final envelope = await cipher.wrap(
      vaultKey: _hex(_vaultKeyHex),
      recipient: _recipient,
      ephemeralPrivateKey: _hex(
        '6e0de9b28a644de27d7b704a66b3b037f0c2be075dd6d3318f7488de0982cfcd',
      ),
      nonce: _hex('000102030405060708090a0b'),
    );

    expect(envelope.toMap(), {
      'version': 1,
      'suite': 'P256-HKDF-SHA256-AES256GCM',
      'recipientKeyID': '9e396cb4f62b15eb7e31cb20fcd9927239cda600ae6e92175c871e6a495a5e16',
      'ephemeralPublicKey':
          'BATHTCD3VkZwlvRJ7sy1VNYNA5chnUzmMKUwupeVV0UgKsl8/xujScp5UX5WZCxsokG+7t5NUgjMxOwhqBiAcZw=',
      'sealedKey':
          'AAECAwQFBgcICQoLhgHaQl/f3n5Gve4W15YOFyrhsFId7yDYDRIL+r+26ZTkj0U4S1glOtqgfFlFPY+2',
    });
  });

  test('unwrap matches the Swift-generated conformance vector', () async {
    final cipher = KeyEnvelopeCipher();

    final vaultKey = await cipher.unwrap(
      sharedSecret: _hex(
        '68f57d2b33bd21fff1465bcad4ca6ddd6d1e1494734e33bdd6a927ebc94461ab',
      ),
      envelope: const VaultKeyEnvelope(
        version: 1,
        suite: 'P256-HKDF-SHA256-AES256GCM',
        recipientKeyId:
            '9e396cb4f62b15eb7e31cb20fcd9927239cda600ae6e92175c871e6a495a5e16',
        ephemeralPublicKey:
            'BATHTCD3VkZwlvRJ7sy1VNYNA5chnUzmMKUwupeVV0UgKsl8/xujScp5UX5WZCxsokG+7t5NUgjMxOwhqBiAcZw=',
        sealedKey:
            'AAECAwQFBgcICQoLhgHaQl/f3n5Gve4W15YOFyrhsFId7yDYDRIL+r+26ZTkj0U4S1glOtqgfFlFPY+2',
      ),
    );

    expect(vaultKey, _hex(_vaultKeyHex));
  });

  test('rejects a recipient whose key id does not match its public key', () {
    final cipher = KeyEnvelopeCipher();

    expect(
      () => cipher.wrap(
        vaultKey: _hex(_vaultKeyHex),
        recipient: const RecipientPublicKey(
          version: 1,
          suite: 'P256-HKDF-SHA256-AES256GCM',
          keyId:
              '0000000000000000000000000000000000000000000000000000000000000000',
          publicKey:
              'BIfIHcCB7b7C5x3L/pON4S38KJMJJgNjN8hSV/BFO0uHdWnKTq+zMm2j3s6GoM+x4fTYqltEk+BiC5ZDghZdaN4=',
        ),
      ),
      throwsFormatException,
    );
  });

  test('detects a tampered sealed key', () async {
    final cipher = KeyEnvelopeCipher();

    final sealedKey = base64Decode(
      'AAECAwQFBgcICQoLhgHaQl/f3n5Gve4W15YOFyrhsFId7yDYDRIL+r+26ZTkj0U4S1glOtqgfFlFPY+2',
    );
    sealedKey[sealedKey.length - 1] ^= 1;

    await expectLater(
      cipher.unwrap(
        sharedSecret: _hex(
          '68f57d2b33bd21fff1465bcad4ca6ddd6d1e1494734e33bdd6a927ebc94461ab',
        ),
        envelope: VaultKeyEnvelope(
          version: 1,
          suite: 'P256-HKDF-SHA256-AES256GCM',
          recipientKeyId:
              '9e396cb4f62b15eb7e31cb20fcd9927239cda600ae6e92175c871e6a495a5e16',
          ephemeralPublicKey:
              'BATHTCD3VkZwlvRJ7sy1VNYNA5chnUzmMKUwupeVV0UgKsl8/xujScp5UX5WZCxsokG+7t5NUgjMxOwhqBiAcZw=',
          sealedKey: base64Encode(sealedKey),
        ),
      ),
      throwsA(anything),
    );
  });
}

Uint8List _hex(String value) {
  final result = Uint8List(value.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}
