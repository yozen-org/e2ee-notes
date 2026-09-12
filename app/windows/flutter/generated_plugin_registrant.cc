// clang-format off

#include "generated_plugin_registrant.h"

#include <secure_keys/secure_keys_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  SecureKeysPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SecureKeysPluginCApi"));
}
