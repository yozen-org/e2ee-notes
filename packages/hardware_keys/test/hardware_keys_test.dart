import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_keys/hardware_keys.dart';
import 'package:hardware_keys/hardware_keys_platform_interface.dart';
import 'package:hardware_keys/hardware_keys_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHardwareKeysPlatform
    with MockPlatformInterfaceMixin
    implements HardwareKeysPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final HardwareKeysPlatform initialPlatform = HardwareKeysPlatform.instance;

  test('$MethodChannelHardwareKeys is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHardwareKeys>());
  });

  test('getPlatformVersion', () async {
    HardwareKeys hardwareKeysPlugin = HardwareKeys();
    MockHardwareKeysPlatform fakePlatform = MockHardwareKeysPlatform();
    HardwareKeysPlatform.instance = fakePlatform;

    expect(await hardwareKeysPlugin.getPlatformVersion(), '42');
  });
}
