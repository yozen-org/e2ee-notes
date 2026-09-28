import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('secure_keys');
  const keystore = MethodChannelAndroidKeystoreKeys();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Android Keystore channel passes key bytes and record in both directions',
      () async {
    final key = Uint8List(32);
    final iv = Uint8List(12);
    final ciphertext = Uint8List.fromList([1, 2, 3, 4]);
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'keystoreIsAvailable':
          return true;
        case 'keystoreProtect':
          expect(call.arguments, key);
          return <String, Object?>{
            'alias': 'alias-1',
            'iv': iv,
            'ciphertext': ciphertext,
          };
        case 'keystoreUnprotect':
          expect(call.arguments, {
            'alias': 'alias-1',
            'iv': iv,
            'ciphertext': ciphertext,
          });
          return key;
        default:
          fail('Unexpected method: ${call.method}');
      }
    });
    expect(await keystore.isAvailable(), isTrue);
    final protected = await keystore.protect(key);
    expect(protected.alias, 'alias-1');
    expect(protected.iv, iv);
    expect(protected.ciphertext, ciphertext);
    expect(await keystore.unprotect(protected), key);
  });

  test('Android Keystore errors reach the caller', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'keystore_error', message: 'Access denied');
    });
    await expectLater(keystore.isAvailable(), throwsA(isA<PlatformException>()));
    await expectLater(
      keystore.protect(Uint8List(32)),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      keystore.unprotect(
        ProtectedVaultKey(
          alias: 'a',
          iv: Uint8List(12),
          ciphertext: Uint8List(1),
        ),
      ),
      throwsA(isA<PlatformException>()),
    );
  });
}
