import 'dart:typed_data';

// 暗号化済みのバイト列だけを扱う保存先の契約。保管庫の鍵や平文には触れない。
abstract interface class BlobStore {
  Future<Uint8List> get(String key);
  // 同じキーに異なる内容を上書きせず、競合として扱う。
  Future<void> putIfAbsent(String key, Uint8List value);
  Future<List<String>> list(String prefix);

  /// プロトコルに従って不要なオブジェクトを回収するための操作。
  Future<void> delete(String key);
}

sealed class StorageException implements Exception {
  const StorageException(this.key);
  final String key;
}

final class ObjectNotFound extends StorageException {
  const ObjectNotFound(super.key);
}

// 既存オブジェクトと保存しようとした内容が異なる場合のエラー。
final class ObjectConflict extends StorageException {
  const ObjectConflict(super.key);
}
