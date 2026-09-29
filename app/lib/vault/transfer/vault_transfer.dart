import 'dart:convert';
import 'dart:typed_data';

import 'package:secure_keys/secure_keys.dart';

/// A one-time package that hands a vault to another device: the vault key
/// wrapped for the recipient plus every object in the vault's [BlobStore].
final class VaultTransfer {
  const VaultTransfer({required this.vaultKeyEnvelope, required this.objects});

  final VaultKeyEnvelope vaultKeyEnvelope;
  final Map<String, Uint8List> objects;

  Map<String, Object> toJson() => {
    'version': 1,
    'vaultKeyEnvelope': vaultKeyEnvelope.toMap(),
    'objects': {
      for (final entry in objects.entries) entry.key: base64Encode(entry.value),
    },
  };

  factory VaultTransfer.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw const FormatException('unsupported vault transfer version');
    }
    final rawObjects = json['objects'] as Map<String, Object?>;
    return VaultTransfer(
      vaultKeyEnvelope: VaultKeyEnvelope.fromMap(
        json['vaultKeyEnvelope'] as Map<String, dynamic>,
      ),
      objects: rawObjects.map(
        (key, value) => MapEntry(key, base64Decode(value as String)),
      ),
    );
  }
}
