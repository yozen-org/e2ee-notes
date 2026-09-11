import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

enum NoteOperationKind { create, update, delete }

// 暗号化する前のメモ操作。JSONのフィールド名と順序はspec/OPERATION_V1.mdに従う。
final class NoteOperation {
  const NoteOperation({
    required this.operationId,
    required this.noteId,
    required this.deviceId,
    required this.sequence,
    required this.timestampMicros,
    required this.kind,
    this.baseOperationId,
    this.title,
    this.body,
  });

  final String operationId;
  final String noteId;
  final String deviceId;
  final int sequence;
  final int timestampMicros;
  final NoteOperationKind kind;
  final String? baseOperationId;
  final String? title;
  final String? body;

  Map<String, Object?> toJson() => {
    'version': 1,
    'operationID': operationId,
    'noteID': noteId,
    'deviceID': deviceId,
    'sequence': sequence,
    'timestampMicros': timestampMicros,
    'kind': kind.name,
    'baseOperationID': ?baseOperationId,
    'title': ?title,
    'body': ?body,
  };

  factory NoteOperation.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw const FormatException('unsupported operation version');
    }
    final kindName = json['kind'] as String;
    return NoteOperation(
      operationId: json['operationID'] as String,
      noteId: json['noteID'] as String,
      deviceId: json['deviceID'] as String,
      sequence: json['sequence'] as int,
      timestampMicros: json['timestampMicros'] as int,
      kind: NoteOperationKind.values.byName(kindName),
      baseOperationId: json['baseOperationID'] as String?,
      title: json['title'] as String?,
      body: json['body'] as String?,
    );
  }

  // テストベクターを再現できるように、一定の順序・空白なしのUTF-8 JSONを生成する。
  Uint8List encodeCanonical() =>
      Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
}

// 保存用の外側の形式。バイト列はJSON出力時にbase64へ変換する。
final class EncryptedOperation {
  const EncryptedOperation({
    required this.objectId,
    required this.nonce,
    required this.ciphertext,
  });

  static const version = 1;
  static const suite = 'AES-256-GCM';

  final String objectId;
  final Uint8List nonce;

  /// AES-GCMの暗号文に16バイトの認証タグを連結したもの。
  final Uint8List ciphertext;

  Map<String, Object> toJson() => {
    'version': version,
    'suite': suite,
    'objectID': objectId,
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(ciphertext),
  };

  factory EncryptedOperation.fromJson(Map<String, Object?> json) {
    if (json['version'] != version || json['suite'] != suite) {
      throw const FormatException('unsupported encrypted operation format');
    }
    return EncryptedOperation(
      objectId: json['objectID'] as String,
      nonce: base64Decode(json['nonce'] as String),
      ciphertext: base64Decode(json['ciphertext'] as String),
    );
  }
}

// AES-256-GCMで操作を暗号化し、復号時には改ざんとIDの不一致を検証する。
final class OperationCipher {
  OperationCipher({AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  static const _aadPrefix = 'yozen.e2ee-notes.operation.v1:';
  static final _objectIdPattern = RegExp(r'^[0-9a-f]{64}$');
  final AesGcm _algorithm;

  Future<EncryptedOperation> encrypt({
    required NoteOperation operation,
    required Uint8List vaultKey,
    required String objectId,
    Uint8List? nonce,
  }) async {
    _validate(vaultKey, objectId);
    // 通常は毎回新しいnonceを生成する。指定可能なのは固定テストベクターの再現のため。
    final actualNonce = nonce ?? Uint8List.fromList(_algorithm.newNonce());
    if (actualNonce.length != 12) {
      throw ArgumentError.value(
        actualNonce.length,
        'nonce length',
        'must be 12',
      );
    }
    final box = await _algorithm.encrypt(
      operation.encodeCanonical(),
      secretKey: SecretKey(vaultKey),
      nonce: actualNonce,
      aad: _aad(objectId),
    );
    return EncryptedOperation(
      objectId: objectId,
      nonce: Uint8List.fromList(box.nonce),
      ciphertext: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    );
  }

  Future<NoteOperation> decrypt({
    required EncryptedOperation encrypted,
    required Uint8List vaultKey,
    required String storageObjectId,
  }) async {
    _validate(vaultKey, storageObjectId);
    if (encrypted.objectId != storageObjectId) {
      throw const FormatException('storage and encrypted object IDs differ');
    }
    if (encrypted.nonce.length != 12 || encrypted.ciphertext.length < 16) {
      throw const FormatException('invalid AES-GCM object lengths');
    }
    // 末尾16バイトの認証タグを分離し、認証に成功した平文だけを読み取る。
    final tagOffset = encrypted.ciphertext.length - 16;
    final plaintext = await _algorithm.decrypt(
      SecretBox(
        encrypted.ciphertext.sublist(0, tagOffset),
        nonce: encrypted.nonce,
        mac: Mac(encrypted.ciphertext.sublist(tagOffset)),
      ),
      secretKey: SecretKey(vaultKey),
      aad: _aad(storageObjectId),
    );
    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('operation must be a JSON object');
    }
    final operation = NoteOperation.fromJson(decoded);
    if (operation.operationId != storageObjectId) {
      throw const FormatException('operation and storage object IDs differ');
    }
    return operation;
  }

  // 保存オブジェクトIDも認証対象にして、別の保存キーへの暗号文の移し替えを検出する。
  List<int> _aad(String objectId) => utf8.encode('$_aadPrefix$objectId');

  void _validate(Uint8List vaultKey, String objectId) {
    if (vaultKey.length != 32) {
      throw ArgumentError.value(
        vaultKey.length,
        'vaultKey length',
        'must be 32',
      );
    }
    if (!_objectIdPattern.hasMatch(objectId)) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'must be 64 lowercase hex characters',
      );
    }
  }
}
