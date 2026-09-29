import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';
import 'package:secure_keys/src/envelope_secure_key.dart';
import 'package:secure_keys/src/software_secure_key.dart';

import 'support/fake_android_keystore_keys.dart';
import 'support/fake_secure_enclave_keys.dart';
import 'support/fake_tpm_keys.dart';

void main() {
  const hardware = KeyPolicy();
  const software = KeyPolicy(allowSoftware: true);
  for (final provider in ['apple', 'tpm', 'android']) {
    test(
      '$provider returns a 32-byte key and opens a serialized record',
      () async {
        final adapter = switch (provider) {
          'apple' => EnvelopeSecureKey(
            backend: FakeSecureEnclaveKeys(),
            provider: 'secure-enclave',
          ),
          'android' => EnvelopeSecureKey(
            backend: FakeAndroidKeystoreKeys(),
            provider: 'android-keystore',
          ),
          _ => EnvelopeSecureKey(
            backend: FakeTpmKeys(),
            provider: 'tpm',
          ),
        };
        final keys = PlatformSecureKey.withHardware(adapter);
        final generated = await keys.generate(policy: hardware);
        expect(generated.vaultKey, hasLength(32));
        final reopened = PlatformSecureKey.withHardware(adapter);
        expect(
          await reopened.open(KeyRecord.decode(generated.record.encode())),
          generated.vaultKey,
        );
        final exposed = generated.vaultKey..[0] ^= 1;
        expect(generated.vaultKey, isNot(exposed));
        expect(keys.isSoftware(generated.record), isFalse);
      },
    );
  }
  test('software fallback requires explicit permission', () async {
    final keys = PlatformSecureKey.withHardware(SoftwareSecureKey());
    await expectLater(keys.generate(policy: hardware), throwsUnsupportedError);
    final generated = await keys.generate(policy: software);
    expect(await keys.open(generated.record), generated.vaultKey);
    expect(keys.isSoftware(generated.record), isTrue);
    await expectLater(
      keys.generate(
        policy: const KeyPolicy(allowSoftware: true, requireUserPresence: true),
      ),
      throwsUnsupportedError,
    );
  });
  test('existing protected keys never fall back after hardware loss', () async {
    final tpm = FakeTpmKeys();
    final keys = PlatformSecureKey.withHardware(
      EnvelopeSecureKey(backend: tpm, provider: 'tpm'),
    );
    final generated = await keys.generate(policy: hardware);
    tpm.available = false;
    tpm.availabilityChecks = 0;
    await expectLater(keys.open(generated.record), throwsStateError);
    expect(tpm.availabilityChecks, 0);
    expect(tpm.keys, hasLength(1));
  });
  test('corrupt shared secret prevents returning persistence data', () async {
    for (final short in [false, true]) {
      final tpm = FakeTpmKeys()
        ..transformSharedSecret = (shared) =>
            short ? Uint8List(31) : (shared..[0] ^= 1);
      final keys = PlatformSecureKey.withHardware(
        EnvelopeSecureKey(backend: tpm, provider: 'tpm'),
      );
      await expectLater(keys.generate(policy: hardware), throwsA(anything));
    }
  });
  test('user presence policy reaches the native adapter', () async {
    final native = FakeSecureEnclaveKeys();
    final keys = PlatformSecureKey.withHardware(
      EnvelopeSecureKey(backend: native, provider: 'secure-enclave'),
    );
    await keys.generate(policy: const KeyPolicy(requireUserPresence: true));
    expect(native.requestedUserPresence, isTrue);
    final tpm = FakeTpmKeys();
    await expectLater(
      PlatformSecureKey.withHardware(
        EnvelopeSecureKey(backend: tpm, provider: 'tpm'),
      ).generate(policy: const KeyPolicy(requireUserPresence: true)),
      throwsUnsupportedError,
    );
    expect(tpm.keys, isEmpty);
    final android = FakeAndroidKeystoreKeys();
    await expectLater(
      PlatformSecureKey.withHardware(
        EnvelopeSecureKey(backend: android, provider: 'android-keystore'),
      ).generate(policy: const KeyPolicy(requireUserPresence: true)),
      throwsUnsupportedError,
    );
    expect(android.keys, isEmpty);
  });
  test(
    'sharing uses the recipient public key and restores the same vault key',
    () async {
      final keys = PlatformSecureKey.withHardware(
        EnvelopeSecureKey(backend: FakeSecureEnclaveKeys(), provider: 'secure-enclave'),
      );
      final source = await keys.generate(policy: hardware);
      final recipient = await keys.createRecipientKey(policy: hardware);
      final envelope = await keys.envelope(source.vaultKey, recipient.publicKey);
      final accepted = await keys.accept(envelope, recipient, policy: hardware);
      expect(accepted.vaultKey, source.vaultKey);
      expect(await keys.open(accepted.record), source.vaultKey);
    },
  );
  test('TPM advertises sharing as supported', () async {
    final keys = PlatformSecureKey.withHardware(
      EnvelopeSecureKey(backend: FakeTpmKeys(), provider: 'tpm'),
    );
    expect((await keys.capabilities()).sharing, isTrue);
    final generated = await keys.generate(policy: hardware);
    await expectLater(keys.publicKey(generated.record), completes);
  });
  test('Android Keystore advertises sharing as supported', () async {
    final keys = PlatformSecureKey.withHardware(
      EnvelopeSecureKey(backend: FakeAndroidKeystoreKeys(), provider: 'android-keystore'),
    );
    expect((await keys.capabilities()).sharing, isTrue);
    final generated = await keys.generate(policy: hardware);
    await expectLater(keys.publicKey(generated.record), completes);
  });
  test('unknown record versions and providers fail closed', () async {
    expect(
      () => KeyRecord.decode(
        Uint8List.fromList(
          utf8.encode('{"version":2,"provider":"software","data":{}}'),
        ),
      ),
      throwsFormatException,
    );
    final keys = PlatformSecureKey.withHardware(
      EnvelopeSecureKey(backend: FakeTpmKeys(), provider: 'tpm'),
    );
    await expectLater(
      keys.open(KeyRecord('unknown', {})),
      throwsFormatException,
    );
  });
}
