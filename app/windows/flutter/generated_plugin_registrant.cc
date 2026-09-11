// clang-format off

#include "generated_plugin_registrant.h"

#include <hardware_keys/hardware_keys_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  HardwareKeysPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("HardwareKeysPluginCApi"));
}
