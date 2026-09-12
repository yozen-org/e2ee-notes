#include "secure_keys_plugin.h"
#include "tpm_key_store.h"

#include <windows.h>

#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <stdexcept>

namespace secure_keys {

void SecureKeysPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "secure_keys",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<SecureKeysPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

SecureKeysPlugin::SecureKeysPlugin() {}

SecureKeysPlugin::~SecureKeysPlugin() {}

void SecureKeysPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    const TpmKeyStore tpm;
    const auto& method = method_call.method_name();
    if (method == "tpmIsAvailable") {
      result->Success(flutter::EncodableValue(tpm.IsAvailable()));
      return;
    }
    if (method == "tpmProtect" || method == "tpmUnprotect") {
      const auto* arguments = method_call.arguments();
      const auto* bytes = arguments ? std::get_if<std::vector<uint8_t>>(arguments) : nullptr;
      if (!bytes || bytes->size() > 8192) {
        result->Error("invalid_arguments", "Expected key bytes");
        return;
      }
      result->Success(flutter::EncodableValue(
          method == "tpmProtect" ? tpm.Protect(*bytes) : tpm.Unprotect(*bytes)));
      return;
    }
  } catch (const std::exception& error) {
    result->Error("tpm_error", error.what());
    return;
  }
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else {
    result->NotImplemented();
  }
}

}
