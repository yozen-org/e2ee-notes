import 'package:e2ee_notes/vault/key_policy/request_key_policy.dart';
import 'package:e2ee_notes/vault/opened_vault.dart';
import 'package:e2ee_notes/vault/vault_opener/vault_opener.dart';

final class CallbackVaultOpener implements VaultOpener {
  const CallbackVaultOpener(this._open);

  final Future<OpenedVault> Function(RequestKeyPolicy requestKeyPolicy) _open;

  @override
  Future<OpenedVault> open({required RequestKeyPolicy requestKeyPolicy}) =>
      _open(requestKeyPolicy);
}
