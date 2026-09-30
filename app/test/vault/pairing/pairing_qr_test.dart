import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';
import 'package:e2ee_notes/vault/pairing/pairing_qr.dart';

void main() {
  const recipient = RecipientPublicKey(
    version: 1,
    suite: 'P256-HKDF-SHA256-AES256GCM',
    keyId: 'key-id',
    publicKey: 'public',
  );

  test('recipient QR round-trips', () {
    final restored = decodeRecipientQr(encodeRecipientQr(recipient));
    expect(restored.toMap(), recipient.toMap());
  });

  test('envelope QR round-trips', () {
    const envelope = VaultKeyEnvelope(
      version: 1,
      suite: 'P256-HKDF-SHA256-AES256GCM',
      recipientKeyId: 'id',
      ephemeralPublicKey: 'ephemeral',
      sealedKey: 'sealed',
    );

    final restored = decodeEnvelopeQr(encodeEnvelopeQr(envelope));
    expect(restored.toMap(), envelope.toMap());
  });

  test('wrong kind fails closed', () {
    expect(() => decodeRecipientQr(encodeEnvelopeQr(
      const VaultKeyEnvelope(
        version: 1,
        suite: 'P256-HKDF-SHA256-AES256GCM',
        recipientKeyId: 'id',
        ephemeralPublicKey: 'ephemeral',
        sealedKey: 'sealed',
      ),
    )), throwsFormatException);
  });
}
