
import 'hardware_keys_platform_interface.dart';

class HardwareKeys {
  Future<String?> getPlatformVersion() {
    return HardwareKeysPlatform.instance.getPlatformVersion();
  }
}
