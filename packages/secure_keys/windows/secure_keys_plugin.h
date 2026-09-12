#ifndef FLUTTER_PLUGIN_SECURE_KEYS_PLUGIN_H_
#define FLUTTER_PLUGIN_SECURE_KEYS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace secure_keys {

class SecureKeysPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  SecureKeysPlugin();

  virtual ~SecureKeysPlugin();

  SecureKeysPlugin(const SecureKeysPlugin&) = delete;
  SecureKeysPlugin& operator=(const SecureKeysPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}

#endif
