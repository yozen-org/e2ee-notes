#include "tpm_method_handler.h"

#include <glib.h>

#include <cstring>
#include <stdexcept>
#include <vector>

#include "tpm_context.h"
#include "tpm_key_store.h"

namespace {

// Returns a new reference to a map describing a P-256 recipient public key.
FlValue* PublicDocument(const std::vector<uint8_t>& public_key) {
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "version", fl_value_new_int(1));
  fl_value_set_string_take(
      map, "suite", fl_value_new_string("P256-HKDF-SHA256-AES256GCM"));
  g_autofree gchar* key_id = g_compute_checksum_for_data(
      G_CHECKSUM_SHA256, public_key.data(), public_key.size());
  fl_value_set_string_take(map, "keyID", fl_value_new_string(key_id));
  g_autofree gchar* encoded =
      g_base64_encode(public_key.data(), public_key.size());
  fl_value_set_string_take(map, "publicKey", fl_value_new_string(encoded));
  return fl_value_ref(map);
}

std::vector<uint8_t> ReadBytes(FlValue* arguments, const gchar* key) {
  FlValue* value = fl_value_lookup(arguments, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_UINT8_LIST) {
    throw std::invalid_argument("Expected byte value");
  }
  const uint8_t* data = fl_value_get_uint8_list(value);
  return std::vector<uint8_t>(data, data + fl_value_get_length(value));
}

}  // namespace

FlMethodResponse* handle_tpm_method(const gchar* method, FlValue* arguments) {
  try {
    if (strcmp(method, "capabilities") == 0) {
      const bool available = secure_keys::TpmContext::IsDeviceAvailable();
      g_autoptr(FlValue) map = fl_value_new_map();
      fl_value_set_string_take(map, "available", fl_value_new_bool(available));
      fl_value_set_string_take(
          map, "hardwareBacked", fl_value_new_bool(available));
      fl_value_set_string_take(map, "provider", fl_value_new_string("TPM"));
      return FL_METHOD_RESPONSE(fl_method_success_response_new(map));
    }

    secure_keys::TpmContext context("device:/dev/tpmrm0");
    const secure_keys::TpmKeyStore tpm(context.get());

    if (strcmp(method, "createRecipientKey") == 0) {
      const auto key = tpm.CreateRecipientKey();
      g_autoptr(FlValue) map = fl_value_new_map();
      fl_value_set_string_take(
          map, "keyHandle",
          fl_value_new_uint8_list(key.handle.data(), key.handle.size()));
      fl_value_set_string_take(map, "publicKey", PublicDocument(key.public_key));
      return FL_METHOD_RESPONSE(fl_method_success_response_new(map));
    }

    if (strcmp(method, "openRecipientKey") == 0) {
      const auto handle = ReadBytes(arguments, "keyHandle");
      const auto public_key = tpm.OpenRecipientKey(handle);
      return FL_METHOD_RESPONSE(
          fl_method_success_response_new(PublicDocument(public_key)));
    }

    if (strcmp(method, "sharedSecret") == 0) {
      const auto handle = ReadBytes(arguments, "keyHandle");
      const auto peer = ReadBytes(arguments, "peerPublicKey");
      const auto shared = tpm.SharedSecret(handle, peer);
      g_autoptr(FlValue) result =
          fl_value_new_uint8_list(shared.data(), shared.size());
      return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    }

    return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  } catch (const std::exception& error) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("tpm_error", error.what(), nullptr));
  }
}
