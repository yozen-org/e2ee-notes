import 'dart:typed_data';

import '../storage/blob_store.dart';

final class OpenedVault {
  OpenedVault({
    required this.store,
    required Uint8List vaultKey,
    required this.deviceId,
  }) : _vaultKey = Uint8List.fromList(vaultKey);

  final BlobStore store;
  final Uint8List _vaultKey;
  final String deviceId;

  Uint8List get vaultKey => Uint8List.fromList(_vaultKey);
}
