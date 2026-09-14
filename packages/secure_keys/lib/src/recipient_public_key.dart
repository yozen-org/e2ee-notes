final class RecipientPublicKey {
  const RecipientPublicKey({
    required this.version,
    required this.suite,
    required this.keyId,
    required this.publicKey,
  });

  factory RecipientPublicKey.fromMap(Map<Object?, Object?> map) =>
      RecipientPublicKey(
        version: map['version'] as int,
        suite: map['suite'] as String,
        keyId: map['keyID'] as String,
        publicKey: map['publicKey'] as String,
      );

  final int version;
  final String suite;
  final String keyId;
  final String publicKey;

  Map<String, Object> toMap() => {
    'version': version,
    'suite': suite,
    'keyID': keyId,
    'publicKey': publicKey,
  };
}
