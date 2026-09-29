#include "secure_keys_plugin.h"
#include "tpm_key_store.h"

#include <windows.h>
#include <bcrypt.h>
#include <wincrypt.h>

#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace secure_keys {
namespace {

constexpr char kSuite[] = "P256-HKDF-SHA256-AES256GCM";

void Check(SECURITY_STATUS status, const char* operation) {
  if (status != ERROR_SUCCESS) {
    throw std::runtime_error(std::string(operation) + " failed (" +
                             std::to_string(static_cast<uint32_t>(status)) + ")");
  }
}

std::string Sha256Hex(const std::vector<uint8_t>& data) {
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  Check(BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0),
        "Open SHA-256");
  DWORD object_size = 0;
  DWORD result_size = 0;
  Check(BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH,
                          reinterpret_cast<PBYTE>(&object_size), sizeof(object_size),
                          &result_size, 0), "Measure SHA-256");
  std::vector<uint8_t> object(object_size);
  BCRYPT_HASH_HANDLE hash = nullptr;
  Check(BCryptCreateHash(algorithm, &hash, object.data(), object_size, nullptr, 0, 0),
        "Create SHA-256 hash");
  Check(BCryptHashData(hash, const_cast<PUCHAR>(data.data()),
                       static_cast<ULONG>(data.size()), 0), "Hash public key");
  std::array<uint8_t, 32> digest{};
  Check(BCryptFinishHash(hash, digest.data(), digest.size(), 0), "Finish SHA-256");
  BCryptDestroyHash(hash);
  BCryptCloseAlgorithmProvider(algorithm, 0);
  std::string hex;
  hex.reserve(64);
  for (uint8_t byte : digest) {
    constexpr char kDigits[] = "0123456789abcdef";
    hex.push_back(kDigits[byte >> 4]);
    hex.push_back(kDigits[byte & 0x0f]);
  }
  return hex;
}

std::string Base64(const std::vector<uint8_t>& data) {
  DWORD size = 0;
  if (data.empty()) return "";
  CryptBinaryToStringA(data.data(), static_cast<DWORD>(data.size()),
                       CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, nullptr, &size);
  std::string encoded(size, '\0');
  CryptBinaryToStringA(data.data(), static_cast<DWORD>(data.size()),
                       CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, encoded.data(),
                       &size);
  encoded.resize(size);
  return encoded;
}

flutter::EncodableMap PublicDocument(const std::vector<uint8_t>& public_key) {
  flutter::EncodableMap document;
  document[flutter::EncodableValue("version")] = flutter::EncodableValue(1);
  document[flutter::EncodableValue("suite")] = flutter::EncodableValue(kSuite);
  document[flutter::EncodableValue("keyID")] =
      flutter::EncodableValue(Sha256Hex(public_key));
  document[flutter::EncodableValue("publicKey")] =
      flutter::EncodableValue(Base64(public_key));
  return document;
}

std::vector<uint8_t> Bytes(const flutter::EncodableMap& map, const char* key) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) throw std::invalid_argument("Missing byte value");
  const auto* bytes = std::get_if<std::vector<uint8_t>>(&it->second);
  if (bytes == nullptr) throw std::invalid_argument("Expected byte value");
  return *bytes;
}

}

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
  const auto& method = method_call.method_name();
  if (method == "getPlatformVersion") {
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
    return;
  }

  try {
    const TpmKeyStore tpm;
    if (method == "capabilities") {
      const bool available = tpm.IsAvailable();
      flutter::EncodableMap map;
      map[flutter::EncodableValue("available")] = flutter::EncodableValue(available);
      map[flutter::EncodableValue("hardwareBacked")] =
          flutter::EncodableValue(available);
      map[flutter::EncodableValue("provider")] = flutter::EncodableValue("TPM");
      result->Success(flutter::EncodableValue(map));
      return;
    }
    if (method == "createRecipientKey") {
      const auto key = tpm.CreateRecipientKey();
      flutter::EncodableMap map;
      map[flutter::EncodableValue("keyHandle")] =
          flutter::EncodableValue(key.handle);
      map[flutter::EncodableValue("publicKey")] =
          flutter::EncodableValue(PublicDocument(key.public_key));
      result->Success(flutter::EncodableValue(map));
      return;
    }
    const auto* arguments =
        method_call.arguments() ? std::get_if<flutter::EncodableMap>(method_call.arguments())
                                : nullptr;
    if (arguments == nullptr) {
      result->Error("invalid_arguments", "Expected a map");
      return;
    }
    if (method == "openRecipientKey") {
      const auto public_key = tpm.OpenRecipientKey(Bytes(*arguments, "keyHandle"));
      result->Success(flutter::EncodableValue(PublicDocument(public_key)));
      return;
    }
    if (method == "sharedSecret") {
      const auto shared = tpm.SharedSecret(Bytes(*arguments, "keyHandle"),
                                           Bytes(*arguments, "peerPublicKey"));
      result->Success(flutter::EncodableValue(shared));
      return;
    }
    result->NotImplemented();
  } catch (const std::exception& error) {
    result->Error("tpm_error", error.what());
  }
}

}
