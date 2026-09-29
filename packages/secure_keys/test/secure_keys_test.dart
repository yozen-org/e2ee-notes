import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_enclave.dart';
import 'package:secure_keys/src/secure_enclave/secure_enclave_keys_method_channel.dart';
import 'package:secure_keys/src/secure_enclave/secure_enclave_keys_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class FakeSecureEnclaveKeysPlatform
    with MockPlatformInterfaceMixin
    implements SecureEnclaveKeysPlatform {
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
  Future<RecipientKey> openRecipientKey(Uint8List keyHandle) async =>
      RecipientKey(
        handle: keyHandle,
        publicKey: (await createRecipientKey(requireUserPresence: false))
            .publicKey,
      );

  @override
  Future<Uint8List> sharedSecret({
    required Uint8List keyHandle,
    required Uint8List peerPublicKey,
  }) async => Uint8List(32);
}

void main() {
  test('$MethodChannelSecureEnclaveKeys is the default instance', () {
    expect(
      SecureEnclaveKeysPlatform.instance,
      isA<MethodChannelSecureEnclaveKeys>(),
    );
  });

  test('facade delegates typed hardware-key operations', () async {
    SecureEnclaveKeysPlatform.instance = FakeSecureEnclaveKeysPlatform();
    final hardwareKeys = SecureEnclaveKeys();
    final capabilities = await hardwareKeys.capabilities();
    final recipient = await hardwareKeys.createRecipientKey();
    final shared = await hardwareKeys.sharedSecret(
      keyHandle: recipient.handle,
      peerPublicKey: Uint8List(65),
    );

    expect(capabilities.hardwareBacked, isTrue);
    expect(recipient.handle, [1]);
    final reopened = await hardwareKeys.openRecipientKey(recipient.handle);
    expect(reopened.handle, recipient.handle);
    expect(reopened.publicKey.toMap(), recipient.publicKey.toMap());
    expect(shared, hasLength(32));
  });
}
