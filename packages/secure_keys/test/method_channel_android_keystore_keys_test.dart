import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('secure_keys');
  final keystore = AndroidKeystoreKeys();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Android Keystore channel passes key handles and public keys', () async {
    final handle = Uint8List.fromList([1, 2]);
    final peer = Uint8List.fromList([65]);
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'capabilities':
          return {
            'available': true,
            'hardwareBacked': true,
            'provider': 'Android Keystore',
          };
        case 'createRecipientKey':
          return {
            'keyHandle': handle,
            'publicKey': {
              'version': 1,
              'suite': 'P256-HKDF-SHA256-AES256GCM',
              'keyID': 'id',
              'publicKey': 'public',
            },
          };
        case 'openRecipientKey':
          expect((call.arguments as Map)['keyHandle'], handle);
          return {
            'version': 1,
            'suite': 'P256-HKDF-SHA256-AES256GCM',
            'keyID': 'id',
            'publicKey': 'public',
          };
        case 'sharedSecret':
          expect((call.arguments as Map)['keyHandle'], handle);
          expect((call.arguments as Map)['peerPublicKey'], peer);
          return Uint8List(32);
        default:
          fail('Unexpected method: ${call.method}');
      }
    });

    final capabilities = await keystore.capabilities();
    expect(capabilities.hardwareBacked, isTrue);
    expect(capabilities.sharing, isTrue);
    expect(capabilities.userPresence, isFalse);

    final recipient = await keystore.createRecipientKey(
      requireUserPresence: false,
    );
    expect(recipient.handle, handle);
    final reopened = await keystore.openRecipientKey(recipient.handle);
    expect(reopened.publicKey.toMap(), recipient.publicKey.toMap());
    final shared = await keystore.sharedSecret(
      keyHandle: recipient.handle,
      peerPublicKey: peer,
    );
    expect(shared, hasLength(32));
  });

  test('Android Keystore errors reach the caller', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'keystore_error', message: 'Access denied');
    });
    await expectLater(
      keystore.capabilities(),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      keystore.createRecipientKey(requireUserPresence: false),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      keystore.sharedSecret(
        keyHandle: Uint8List.fromList([1]),
        peerPublicKey: Uint8List.fromList([65]),
      ),
      throwsA(isA<PlatformException>()),
    );
  });
}
