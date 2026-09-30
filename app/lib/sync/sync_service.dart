import '../storage/blob_store.dart';

/// Merges two append-only [BlobStore]s in both directions.
///
/// The operation log is immutable, so there is no conflict resolution: objects
/// missing on one side are simply copied over.
Future<void> syncBlobStores(BlobStore local, BlobStore remote) async {
  final localKeys = (await local.list('')).toSet();
  final remoteKeys = (await remote.list('')).toSet();

  for (final key in remoteKeys.difference(localKeys)) {
    await local.putIfAbsent(key, await remote.get(key));
  }
  for (final key in localKeys.difference(remoteKeys)) {
    await remote.putIfAbsent(key, await local.get(key));
  }
}
