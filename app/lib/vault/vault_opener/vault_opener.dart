import '../opened_vault.dart';
import '../key_policy/request_key_policy.dart';

abstract interface class VaultOpener {
  Future<OpenedVault> open({required RequestKeyPolicy requestKeyPolicy});
}
