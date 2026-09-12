// clang-format off

#include "generated_plugin_registrant.h"

#include <secure_keys/secure_keys_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) secure_keys_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "SecureKeysPlugin");
  secure_keys_plugin_register_with_registrar(secure_keys_registrar);
}
