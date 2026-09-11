import 'dart:io';
import 'dart:typed_data';

abstract interface class VaultKeyProvider {
  Future<Uint8List> openKey(Directory root);
}
