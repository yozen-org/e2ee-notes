#ifndef FLUTTER_PLUGIN_HARDWARE_KEYS_PLUGIN_H_
#define FLUTTER_PLUGIN_HARDWARE_KEYS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace hardware_keys {

class HardwareKeysPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  HardwareKeysPlugin();

  virtual ~HardwareKeysPlugin();

  // Disallow copy and assign.
  HardwareKeysPlugin(const HardwareKeysPlugin&) = delete;
  HardwareKeysPlugin& operator=(const HardwareKeysPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace hardware_keys

#endif  // FLUTTER_PLUGIN_HARDWARE_KEYS_PLUGIN_H_
