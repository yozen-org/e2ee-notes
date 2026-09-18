import 'opened_vault.dart';
import 'request_key_policy.dart';

typedef VaultOpener = Future<OpenedVault> Function(
  RequestKeyPolicy requestPolicy,
);
