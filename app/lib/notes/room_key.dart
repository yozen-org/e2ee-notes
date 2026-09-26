import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../storage/blob_store.dart';
import 'room.dart';

final class EncryptedRoomKey {
  const EncryptedRoomKey({required this.nonce, required this.ciphertext});

  static const suite = 'AES-256-GCM';

  final Uint8List nonce;
  final Uint8List ciphertext;

  Map<String, Object> toJson() => {
    'suite': suite,
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(ciphertext),
  };

  factory EncryptedRoomKey.fromJson(Map<String, Object?> json) {
    if (json['suite'] != suite) {
      throw const FormatException('unsupported room key format');
    }
    return EncryptedRoomKey(
      nonce: base64Decode(json['nonce'] as String),
      ciphertext: base64Decode(json['ciphertext'] as String),
    );
  }
}

final class RoomKeyCipher {
  RoomKeyCipher({AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  static const _aadPrefix = 'yozen.e2ee-notes.room-key.v1:';

  final AesGcm _algorithm;

  Future<EncryptedRoomKey> wrap({
    required Uint8List rootKey,
    required Uint8List roomKey,
    required String roomId,
  }) async {
    final box = await _algorithm.encrypt(
      roomKey,
      secretKey: SecretKey(rootKey),
      nonce: _algorithm.newNonce(),
      aad: _aad(roomId),
    );
    return EncryptedRoomKey(
      nonce: Uint8List.fromList(box.nonce),
      ciphertext: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    );
  }

  Future<Uint8List> unwrap({
    required Uint8List rootKey,
    required EncryptedRoomKey wrapped,
    required String roomId,
  }) async {
    final tagOffset = wrapped.ciphertext.length - 16;
    final clear = await _algorithm.decrypt(
      SecretBox(
        wrapped.ciphertext.sublist(0, tagOffset),
        nonce: wrapped.nonce,
        mac: Mac(wrapped.ciphertext.sublist(tagOffset)),
      ),
      secretKey: SecretKey(rootKey),
      aad: _aad(roomId),
    );
    return Uint8List.fromList(clear);
  }

  List<int> _aad(String roomId) => utf8.encode('$_aadPrefix$roomId');
}

final class RoomKeyStore {
  RoomKeyStore({
    required BlobStore store,
    required Uint8List rootKey,
    RoomKeyCipher? cipher,
    Random? random,
  }) : _store = store, // ignore: prefer_initializing_formals
       _rootKey = Uint8List.fromList(rootKey),
       _cipher = cipher ?? RoomKeyCipher(),
       _random = random ?? Random.secure();

  static const _wrappedKey = 'rooms/$personalRoomId/room-key.json';

  final BlobStore _store;
  final Uint8List _rootKey;
  final RoomKeyCipher _cipher;
  final Random _random;

  Future<Room> loadOrCreate() async {
    if (await _hasWrappedKey()) return _unwrap();
    return _create();
  }

  Future<bool> _hasWrappedKey() async =>
      (await _store.list(_wrappedKey)).contains(_wrappedKey);

  Future<Room> _unwrap() async {
    final decoded = jsonDecode(utf8.decode(await _store.get(_wrappedKey)));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('room key must be a JSON object');
    }
    final key = await _cipher.unwrap(
      rootKey: _rootKey,
      wrapped: EncryptedRoomKey.fromJson(decoded),
      roomId: personalRoomId,
    );
    return Room(id: personalRoomId, key: key);
  }

  Future<Room> _create() async {
    final roomKey = Uint8List.fromList(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
    final wrapped = await _cipher.wrap(
      rootKey: _rootKey,
      roomKey: roomKey,
      roomId: personalRoomId,
    );
    await _store.putIfAbsent(
      _wrappedKey,
      Uint8List.fromList(utf8.encode(jsonEncode(wrapped.toJson()))),
    );
    return Room(id: personalRoomId, key: roomKey);
  }
}
