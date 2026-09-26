import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../storage/blob_store.dart';
import 'room.dart';

final class RoomRecord {
  const RoomRecord({
    required this.roomId,
    required this.nonce,
    required this.ciphertext,
  });

  static const suite = 'AES-256-GCM';

  final String roomId;
  final Uint8List nonce;
  final Uint8List ciphertext;

  Map<String, Object> toJson() => {
    'suite': suite,
    'roomId': roomId,
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(ciphertext),
  };

  factory RoomRecord.fromJson(Map<String, Object?> json) {
    if (json['suite'] != suite) {
      throw const FormatException('unsupported room record format');
    }
    return RoomRecord(
      roomId: json['roomId'] as String,
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

  Future<RoomRecord> wrap({
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
    return RoomRecord(
      roomId: roomId,
      nonce: Uint8List.fromList(box.nonce),
      ciphertext: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    );
  }

  Future<Uint8List> unwrap({
    required Uint8List rootKey,
    required RoomRecord record,
  }) async {
    final tagOffset = record.ciphertext.length - 16;
    final clear = await _algorithm.decrypt(
      SecretBox(
        record.ciphertext.sublist(0, tagOffset),
        nonce: record.nonce,
        mac: Mac(record.ciphertext.sublist(tagOffset)),
      ),
      secretKey: SecretKey(rootKey),
      aad: _aad(record.roomId),
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

  static const _recordKey = 'room.json';

  final BlobStore _store;
  final Uint8List _rootKey;
  final RoomKeyCipher _cipher;
  final Random _random;

  Future<Room> loadOrCreate() async {
    if (await _hasRecord()) return _open();
    return _create();
  }

  Future<bool> _hasRecord() async =>
      (await _store.list(_recordKey)).contains(_recordKey);

  Future<Room> _open() async {
    final decoded = jsonDecode(utf8.decode(await _store.get(_recordKey)));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('room record must be a JSON object');
    }
    final record = RoomRecord.fromJson(decoded);
    final key = await _cipher.unwrap(rootKey: _rootKey, record: record);
    return Room(id: record.roomId, key: key);
  }

  Future<Room> _create() async {
    final roomId = _identifier();
    final roomKey = Uint8List.fromList(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
    final record = await _cipher.wrap(
      rootKey: _rootKey,
      roomKey: roomKey,
      roomId: roomId,
    );
    await _store.putIfAbsent(
      _recordKey,
      Uint8List.fromList(utf8.encode(jsonEncode(record.toJson()))),
    );
    return Room(id: roomId, key: roomKey);
  }

  String _identifier() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
