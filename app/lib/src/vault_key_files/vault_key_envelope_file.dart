import 'dart:convert';
import 'dart:io';

import 'package:hardware_keys/hardware_keys.dart';
import 'package:path/path.dart' as p;

final class VaultKeyEnvelopeFile {
  VaultKeyEnvelopeFile(Directory root)
    : _file = File(p.join(root.path, 'vault-key.envelope.json'));

  final File _file;

  Future<bool> exists() => _file.exists();

  Future<VaultKeyEnvelope> read() async {
    final value = jsonDecode(await _file.readAsString());
    if (value is! Map<String, Object?>) {
      throw const FormatException('expected a JSON object');
    }
    return VaultKeyEnvelope.fromMap(value);
  }

  Future<void> write(VaultKeyEnvelope envelope) async {
    await _file.writeAsString(jsonEncode(envelope.toMap()), flush: true);
  }
}
