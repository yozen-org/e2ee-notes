import '../vault/opened_vault.dart';
import 'exchange_server_settings.dart';
import 'remote_blob_store.dart';
import 'sync_service.dart';
import 'vault_namespace.dart';

/// A hook that syncs a vault against the exchange server.
typedef SyncVault = Future<void> Function(OpenedVault vault);

/// The default exchange server used when none is configured.
const exchangeServerUrl = 'https://e2eenotes.yozen.org';

/// Pulls and pushes the vault's operation log against the exchange server.
///
/// The remote namespace is derived from the vault key, so the server only ever
/// sees an opaque namespace and ciphertext.
Future<void> syncVault(
  OpenedVault vault, {
  String serverUrl = exchangeServerUrl,
}) async {
  final namespace = await vaultNamespace(vault.vaultKey);
  final remote = RemoteBlobStore(baseUrl: serverUrl, namespace: namespace);
  await syncBlobStores(vault.store, remote);
}

/// Syncs without surfacing failures. The vault keeps working locally even when
/// the server is unreachable.
Future<void> syncVaultBestEffort(OpenedVault vault) async {
  try {
    await syncVault(vault, serverUrl: await loadExchangeServerUrl());
  } on Object {
    // Best-effort.
  }
}
