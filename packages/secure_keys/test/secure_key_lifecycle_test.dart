import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';
import 'package:secure_keys/src/secure_enclave/secure_enclave_secure_key.dart';
import 'package:secure_keys/src/tpm/tpm_secure_key.dart';
import 'package:secure_keys/src/software_secure_key.dart';

import 'support/fake_secure_enclave_keys.dart';
import 'support/fake_tpm_keys.dart';

void main() {
  const hardware = KeyPolicy();
  const software = KeyPolicy(allowSoftware: true);
  for (final provider in ['apple', 'tpm']) {
    test(
      '$provider returns a 32-byte key and opens a serialized record',
      () async {
        final adapter = provider == 'apple'
            ? SecureEnclaveSecureKey(FakeSecureEnclaveKeys())
            : TpmSecureKey(FakeTpmKeys());
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
    final keys = PlatformSecureKey.withHardware(TpmSecureKey(tpm));
    final generated = await keys.generate(policy: hardware);
    tpm.available = false;
    tpm.availabilityChecks = 0;
    await expectLater(keys.open(generated.record), throwsStateError);
    expect(tpm.availabilityChecks, 0);
    expect(tpm.keys, hasLength(1));
  });
  test(
    'incorrect and short restored keys prevent returning persistence data',
    () async {
      for (final short in [false, true]) {
        final tpm = FakeTpmKeys()
          ..transformRestored = (key) =>
              short ? Uint8List(31) : (key..[0] ^= 1);
        final keys = PlatformSecureKey.withHardware(TpmSecureKey(tpm));
        await expectLater(
          keys.generate(policy: hardware),
          throwsFormatException,
        );
      }
    },
  );
  test('user presence policy reaches the native adapter', () async {
    final native = FakeSecureEnclaveKeys();
    final keys = PlatformSecureKey.withHardware(SecureEnclaveSecureKey(native));
    await keys.generate(policy: const KeyPolicy(requireUserPresence: true));
    expect(native.requestedUserPresence, isTrue);
    final tpm = FakeTpmKeys();
    await expectLater(
      PlatformSecureKey.withHardware(TpmSecureKey(tpm))
          .generate(policy: const KeyPolicy(requireUserPresence: true)),
      throwsUnsupportedError,
    );
    expect(tpm.keys, isEmpty);
  });
  test(
    'sharing uses the recipient public key and restores the same vault key',
    () async {
      final keys = PlatformSecureKey.withHardware(
        SecureEnclaveSecureKey(FakeSecureEnclaveKeys()),
      );
      final source = await keys.generate(policy: hardware);
      final recipient = await keys.generate(policy: hardware);
      final envelope = await keys.envelope(
        source.vaultKey,
        await keys.publicKey(recipient.record),
      );
      final accepted = await keys.accept(
        envelope,
        recipient.record,
        policy: hardware,
      );
      expect(accepted.vaultKey, source.vaultKey);
      expect(await keys.open(accepted.record), source.vaultKey);
    },
  );
  test('TPM advertises sharing as unsupported', () async {
    final keys = PlatformSecureKey.withHardware(TpmSecureKey(FakeTpmKeys()));
    expect((await keys.capabilities()).sharing, isFalse);
    final generated = await keys.generate(policy: hardware);
    await expectLater(keys.publicKey(generated.record), throwsUnsupportedError);
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
    final keys = PlatformSecureKey.withHardware(TpmSecureKey(FakeTpmKeys()));
    await expectLater(
      keys.open(KeyRecord('unknown', {})),
      throwsFormatException,
    );
  });
}
