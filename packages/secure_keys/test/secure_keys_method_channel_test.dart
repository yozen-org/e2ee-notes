import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/src/secure_enclave/secure_enclave_keys_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = MethodChannelSecureEnclaveKeys();
  const channel = MethodChannel('secure_keys');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'capabilities':
              return {
                'available': true,
                'hardwareBacked': true,
                'provider': 'test',
              };
            case 'createRecipientKey':
              return {
                'keyHandle': Uint8List.fromList([1, 2]),
                'publicKey': {
                  'version': 1,
                  'suite': 'suite',
                  'keyID': 'id',
                  'publicKey': 'public',
                },
              };
            case 'openRecipientKey':
              expect((call.arguments as Map)['keyHandle'], [1, 2]);
              return {
                'version': 1,
                'suite': 'suite',
                'keyID': 'id',
                'publicKey': 'public',
              };
            case 'wrapVaultKey':
              return {
                'version': 1,
                'suite': 'suite',
                'recipientKeyID': 'id',
                'ephemeralPublicKey': 'ephemeral',
                'sealedKey': 'sealed',
              };
            case 'unwrapVaultKey':
              return Uint8List(32);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('method channel preserves typed documents and binary values', () async {
    final capabilities = await platform.capabilities();
    final recipient = await platform.createRecipientKey(
      requireUserPresence: false,
    );
    final envelope = await platform.wrapVaultKey(
      vaultKey: Uint8List(32),
      recipient: recipient.publicKey,
    );
    final unwrapped = await platform.unwrapVaultKey(
      keyHandle: recipient.handle,
      envelope: envelope,
    );

    expect(capabilities.provider, 'test');
    expect(recipient.handle, [1, 2]);
    final reopened = await platform.openRecipientKey(recipient.handle);
    expect(reopened.publicKey.toMap(), recipient.publicKey.toMap());
    expect(reopened.handle, recipient.handle);
    expect(envelope.sealedKey, 'sealed');
    expect(unwrapped, hasLength(32));
  });
}
