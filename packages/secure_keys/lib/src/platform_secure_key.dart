import 'dart:io';
import 'dart:typed_data';

import 'generated_key.dart';
import 'key_capabilities.dart';
import 'key_policy.dart';
import 'key_record.dart';
import 'secure_key.dart';
import 'software_secure_key.dart';
import 'secure_enclave/secure_enclave_keys.dart';
import 'secure_enclave/secure_enclave_secure_key.dart';
import 'tpm/method_channel_tpm_keys.dart';
import 'tpm/tpm_secure_key.dart';

final class PlatformSecureKey extends SecureKey {
  PlatformSecureKey()
    : this.withHardware(switch (Platform.operatingSystem) {
        'macos' || 'ios' => SecureEnclaveSecureKey(SecureEnclaveKeys()),
        'windows' || 'linux' => TpmSecureKey(const MethodChannelTpmKeys()),
        _ => SoftwareSecureKey(),
      });

  /// Dependency injection for native adapter tests.
  PlatformSecureKey.withHardware(this._hardware);
  final SecureKey _hardware;
  final _software = SoftwareSecureKey();

  @override
  Future<KeyCapabilities> capabilities() => _hardware.capabilities();

  @override
  Future<GeneratedKey> protect(
    Uint8List vaultKey, {
    required KeyPolicy policy,
  }) async {
    final hardware = (await capabilities()).hardwareBacked;
    return (hardware ? _hardware : _software).protect(vaultKey, policy: policy);
  }

  @override
  Future<Uint8List> open(KeyRecord record) =>
      (isSoftware(record) ? _software : _hardware).open(record);

  @override
  Future<RecipientPublicKey> publicKey(KeyRecord record) =>
      _hardware.publicKey(record);
  @override
  Future<VaultKeyEnvelope> envelope(
    Uint8List vaultKey,
    RecipientPublicKey recipient,
  ) => _hardware.envelope(vaultKey, recipient);
  @override
  Future<GeneratedKey> accept(
    VaultKeyEnvelope envelope,
    KeyRecord recipient, {
    required KeyPolicy policy,
  }) => _hardware.accept(envelope, recipient, policy: policy);
}
