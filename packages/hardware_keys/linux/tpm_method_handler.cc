#include "tpm_method_handler.h"

#include <cstring>
#include <stdexcept>
#include <vector>

#include "tpm_context.h"
#include "tpm_key_store.h"

FlMethodResponse* handle_tpm_method(const gchar* method, FlValue* arguments) {
  try {
    if (strcmp(method, "tpmIsAvailable") == 0) {
      g_autoptr(FlValue) available = fl_value_new_bool(hardware_keys::TpmContext::IsDeviceAvailable());
      return FL_METHOD_RESPONSE(fl_method_success_response_new(available));
    }
    if (strcmp(method, "tpmProtect") != 0 && strcmp(method, "tpmUnprotect") != 0) {
      return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    }
    if (!arguments || fl_value_get_type(arguments) != FL_VALUE_TYPE_UINT8_LIST ||
        fl_value_get_length(arguments) == 0 || fl_value_get_length(arguments) > 8192) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new("invalid_arguments", "Expected key bytes", nullptr));
    }
    const auto* data = fl_value_get_uint8_list(arguments);
    const std::vector<uint8_t> bytes(data, data + fl_value_get_length(arguments));
    hardware_keys::TpmContext context("device:/dev/tpmrm0");
    const hardware_keys::TpmKeyStore tpm(context.get());
    const auto output = strcmp(method, "tpmProtect") == 0 ? tpm.Protect(bytes) : tpm.Unprotect(bytes);
    g_autoptr(FlValue) result = fl_value_new_uint8_list(output.data(), output.size());
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } catch (const std::exception& error) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("tpm_error", error.what(), nullptr));
  }
}
