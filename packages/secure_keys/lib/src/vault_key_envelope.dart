final class VaultKeyEnvelope {
  const VaultKeyEnvelope({
    required this.version,
    required this.suite,
    required this.recipientKeyId,
    required this.ephemeralPublicKey,
    required this.sealedKey,
  });

  factory VaultKeyEnvelope.fromMap(Map<Object?, Object?> map) =>
      VaultKeyEnvelope(
        version: map['version'] as int,
        suite: map['suite'] as String,
        recipientKeyId: map['recipientKeyID'] as String,
        ephemeralPublicKey: map['ephemeralPublicKey'] as String,
        sealedKey: map['sealedKey'] as String,
      );

  final int version;
  final String suite;
  final String recipientKeyId;
  final String ephemeralPublicKey;
  final String sealedKey;

  Map<String, Object> toMap() => {
    'version': version,
    'suite': suite,
    'recipientKeyID': recipientKeyId,
    'ephemeralPublicKey': ephemeralPublicKey,
    'sealedKey': sealedKey,
  };
}
