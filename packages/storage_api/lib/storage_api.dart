import 'dart:typed_data';

abstract interface class BlobStore {
  Future<Uint8List> get(String key);

  Future<void> putIfAbsent(String key, Uint8List value);
  Future<List<String>> list(String prefix);

  Future<void> delete(String key);
}

sealed class StorageException implements Exception {
  const StorageException(this.key);
  final String key;
}

final class ObjectNotFound extends StorageException {
  const ObjectNotFound(super.key);
}

final class ObjectConflict extends StorageException {
  const ObjectConflict(super.key);
}
