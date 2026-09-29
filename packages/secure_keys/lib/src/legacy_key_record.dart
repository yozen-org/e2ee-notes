import 'dart:convert';
import 'dart:typed_data';

import 'key_record.dart';

/// Read-only import of the app's pre-record layout. The storage adapter only
/// reads these names; interpretation of their contents belongs to this package.
const legacyKeyFiles = [
  'recipient-key.handle',
  'vault-key.envelope.json',
  'vault-key.bin',
];

KeyRecord? importLegacyKeyRecord(Map<String, Uint8List> files) {
  final handle = files['recipient-key.handle'];
  final envelope = files['vault-key.envelope.json'];
  if ((handle != null) != (envelope != null)) {
    throw const FormatException('Incomplete or conflicting legacy key state');
  }
  if (handle != null) {
    return KeyRecord('secure-enclave', {
      'handle': base64Encode(handle),
      'envelope': jsonDecode(utf8.decode(envelope!)),
    });
  }
  final plain = files['vault-key.bin'];
  return plain == null
      ? null
      : KeyRecord('software', {'key': base64Encode(plain)});
}
