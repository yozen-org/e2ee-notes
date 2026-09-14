import '../vault_key_service.dart';

abstract interface class VaultKeySelector {
  Future<VaultKeyService> select();
}
