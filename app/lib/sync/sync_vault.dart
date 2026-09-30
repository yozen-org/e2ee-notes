import '../vault/opened_vault.dart';
import 'remote_blob_store.dart';
import 'sync_service.dart';
import 'vault_namespace.dart';

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
