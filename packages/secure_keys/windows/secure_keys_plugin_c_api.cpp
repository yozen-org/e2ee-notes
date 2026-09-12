#include "include/secure_keys/secure_keys_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "secure_keys_plugin.h"

void SecureKeysPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  secure_keys::SecureKeysPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
