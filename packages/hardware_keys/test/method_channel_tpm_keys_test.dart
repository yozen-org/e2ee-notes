import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_keys/method_channel_tpm_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('hardware_keys');
  const tpm = MethodChannelTpmKeys();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('TPM channel passes opaque bytes in both directions', () async {
    final key = Uint8List(32);
    final blob = Uint8List.fromList([69, 84, 87, 1, 99]);
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'tpmIsAvailable':
          return true;
        case 'tpmProtect':
          expect(call.arguments, key);
          return blob;
        case 'tpmUnprotect':
          expect(call.arguments, blob);
          return key;
        default:
          fail('Unexpected method: ${call.method}');
      }
    });
    expect(await tpm.isAvailable(), isTrue);
    expect(await tpm.protect(key), blob);
    expect(await tpm.unprotect(blob), key);
  });

  test('TPM errors reach the caller', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'tpm_error', message: 'Access denied');
    });
    await expectLater(tpm.isAvailable(), throwsA(isA<PlatformException>()));
    await expectLater(
      tpm.protect(Uint8List(32)),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      tpm.unprotect(Uint8List(4)),
      throwsA(isA<PlatformException>()),
    );
  });
}
