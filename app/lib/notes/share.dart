import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// An X25519 key pair that identifies a participant for sharing a room.
final class ShareKeys {
  ShareKeys({required this.publicKey, required Uint8List privateKey})
    : _privateKey = Uint8List.fromList(privateKey);

  final Uint8List publicKey;
  final Uint8List _privateKey;

  Uint8List get privateKey => Uint8List.fromList(_privateKey);
}

Future<ShareKeys> generateShareKeys() async {
  final keyPair = await X25519().newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final privateKey = await keyPair.extractPrivateKeyBytes();
  return ShareKeys(
    publicKey: Uint8List.fromList(publicKey.bytes),
    privateKey: Uint8List.fromList(privateKey),
  );
}

/// A serializable invitation that lets a recipient recover a room key.
final class RoomInvitation {
  const RoomInvitation({
    required this.roomId,
    required this.inviterPublicKey,
    required this.nonce,
    required this.ciphertext,
  });

  static const suite = 'AES-256-GCM';

  final String roomId;
  final Uint8List inviterPublicKey;
  final Uint8List nonce;
  final Uint8List ciphertext;

  Map<String, Object> toJson() => {
    'suite': suite,
    'roomId': roomId,
    'inviterPublicKey': base64Encode(inviterPublicKey),
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(ciphertext),
  };

  factory RoomInvitation.fromJson(Map<String, Object?> json) {
    if (json['suite'] != suite) {
      throw const FormatException('unsupported invitation format');
    }
    return RoomInvitation(
      roomId: json['roomId'] as String,
      inviterPublicKey: base64Decode(json['inviterPublicKey'] as String),
      nonce: base64Decode(json['nonce'] as String),
      ciphertext: base64Decode(json['ciphertext'] as String),
    );
  }
}

final class RoomKeySharer {
  RoomKeySharer({X25519? ecdh, Hkdf? hkdf, AesGcm? aes})
    : _ecdh = ecdh ?? X25519(),
      _hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32),
      _aes = aes ?? AesGcm.with256bits();

  static const _context = 'yozen.e2ee-notes.room-share.v1:';

  final X25519 _ecdh;
  final Hkdf _hkdf;
  final AesGcm _aes;

  Future<RoomInvitation> wrap({
    required Uint8List roomKey,
    required ShareKeys inviter,
    required Uint8List recipientPublicKey,
    required String roomId,
  }) async {
    final wrappingKey = await _deriveWrappingKey(
      inviter,
      recipientPublicKey,
      roomId,
    );
    final box = await _aes.encrypt(
      roomKey,
      secretKey: wrappingKey,
      nonce: _aes.newNonce(),
      aad: utf8.encode(_context + roomId),
    );
    return RoomInvitation(
      roomId: roomId,
      inviterPublicKey: inviter.publicKey,
      nonce: Uint8List.fromList(box.nonce),
      ciphertext: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    );
  }

  Future<Uint8List> unwrap({
    required RoomInvitation invitation,
    required ShareKeys recipient,
  }) async {
    final wrappingKey = await _deriveWrappingKey(
      recipient,
      invitation.inviterPublicKey,
      invitation.roomId,
    );
    final tagOffset = invitation.ciphertext.length - 16;
    final clear = await _aes.decrypt(
      SecretBox(
        invitation.ciphertext.sublist(0, tagOffset),
        nonce: invitation.nonce,
        mac: Mac(invitation.ciphertext.sublist(tagOffset)),
      ),
      secretKey: wrappingKey,
      aad: utf8.encode(_context + invitation.roomId),
    );
    return Uint8List.fromList(clear);
  }

  Future<SecretKey> _deriveWrappingKey(
    ShareKeys self,
    Uint8List remotePublicKey,
    String roomId,
  ) async {
    final sharedSecret = await _ecdh.sharedSecretKey(
      keyPair: SimpleKeyPairData(
        self.privateKey,
        publicKey: SimplePublicKey(self.publicKey, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      ),
      remotePublicKey: SimplePublicKey(
        remotePublicKey,
        type: KeyPairType.x25519,
      ),
    );
    return _hkdf.deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode(_context + roomId),
    );
  }
}
