import '../opened_vault.dart';
import '../key_policy/request_key_policy.dart';

typedef VaultOpener = Future<OpenedVault> Function(
  RequestKeyPolicy requestPolicy,
);
