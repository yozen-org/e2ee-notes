import 'dart:typed_data';

import 'recipient_public_key.dart';

final class RecipientKey {
  const RecipientKey({required this.handle, required this.publicKey});
  final Uint8List handle;
  final RecipientPublicKey publicKey;
}
