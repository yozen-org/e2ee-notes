import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hardware_keys_platform_interface.dart';

/// An implementation of [HardwareKeysPlatform] that uses method channels.
class MethodChannelHardwareKeys extends HardwareKeysPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('hardware_keys');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
