// 代替実装を注入して、公開APIから各鍵操作へ正しく委譲されることを確認する。
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_keys/hardware_keys.dart';
import 'package:hardware_keys/hardware_keys_method_channel.dart';
import 'package:hardware_keys/hardware_keys_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class FakeHardwareKeysPlatform
    with MockPlatformInterfaceMixin
    implements HardwareKeysPlatform {
  @override
  Future<HardwareKeyCapabilities> capabilities() async =>
      const HardwareKeyCapabilities(
        available: true,
        hardwareBacked: true,
        provider: 'Fake enclave',
      );

  @override
  Future<RecipientKey> createRecipientKey({
    required bool requireUserPresence,
  }) async => RecipientKey(
    handle: Uint8List.fromList([1]),
    publicKey: const RecipientPublicKey(
      version: 1,
      suite: 'suite',
      keyId: 'id',
      publicKey: 'key',
    ),
  );

  @override
  Future<Uint8List> unwrapVaultKey({
    required Uint8List keyHandle,
    required VaultKeyEnvelope envelope,
  }) async => Uint8List(32);

  @override
  Future<VaultKeyEnvelope> wrapVaultKey({
    required Uint8List vaultKey,
    required RecipientPublicKey recipient,
  }) async => const VaultKeyEnvelope(
    version: 1,
    suite: 'suite',
    recipientKeyId: 'id',
    ephemeralPublicKey: 'ephemeral',
    sealedKey: 'sealed',
  );
}

void main() {
  test('$MethodChannelHardwareKeys is the default instance', () {
    expect(HardwareKeysPlatform.instance, isA<MethodChannelHardwareKeys>());
  });

  test('facade delegates typed hardware-key operations', () async {
    HardwareKeysPlatform.instance = FakeHardwareKeysPlatform();
    final hardwareKeys = HardwareKeys();
    final capabilities = await hardwareKeys.capabilities();
    final recipient = await hardwareKeys.createRecipientKey();
    final envelope = await hardwareKeys.wrapVaultKey(
      vaultKey: Uint8List(32),
      recipient: recipient.publicKey,
    );
    final key = await hardwareKeys.unwrapVaultKey(
      keyHandle: recipient.handle,
      envelope: envelope,
    );

    expect(capabilities.hardwareBacked, isTrue);
    expect(recipient.handle, [1]);
    expect(envelope.recipientKeyId, 'id');
    expect(key, hasLength(32));
  });
}
