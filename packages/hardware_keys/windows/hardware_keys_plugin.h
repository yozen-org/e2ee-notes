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

  HardwareKeysPlugin(const HardwareKeysPlugin&) = delete;
  HardwareKeysPlugin& operator=(const HardwareKeysPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}

#endif
