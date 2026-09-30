import 'dart:convert';

import 'package:secure_keys/secure_keys.dart';

String encodeRecipientQr(RecipientPublicKey key) =>
    jsonEncode({'kind': 'recipient', 'recipientPublicKey': key.toMap()});

String encodeEnvelopeQr(VaultKeyEnvelope envelope) =>
    jsonEncode({'kind': 'envelope', 'envelope': envelope.toMap()});

RecipientPublicKey decodeRecipientQr(String data) {
  final json = jsonDecode(data) as Map<String, dynamic>;
  if (json['kind'] != 'recipient') {
    throw const FormatException('not a recipient QR code');
  }
  return RecipientPublicKey.fromMap(
    json['recipientPublicKey'] as Map<String, dynamic>,
  );
}

VaultKeyEnvelope decodeEnvelopeQr(String data) {
  final json = jsonDecode(data) as Map<String, dynamic>;
  if (json['kind'] != 'envelope') {
    throw const FormatException('not an envelope QR code');
  }
  return VaultKeyEnvelope.fromMap(json['envelope'] as Map<String, dynamic>);
}
