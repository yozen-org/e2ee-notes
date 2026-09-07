#include "include/hardware_keys/hardware_keys_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "hardware_keys_plugin.h"

void HardwareKeysPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  hardware_keys::HardwareKeysPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
