#include "tpm_key_store.h"

#include <windows.h>
#include <bcrypt.h>
#include <ncrypt.h>
#include <tbs.h>

#include <algorithm>
#include <array>
#include <stdexcept>
#include <string>

namespace hardware_keys {
namespace {

constexpr wchar_t kWrappingKeyName[] = L"yozen.e2ee-notes.vault-wrap.v1";
constexpr std::array<uint8_t, 4> kHeader = {'E', 'T', 'W', 1};
constexpr DWORD kRsaBits = 2048;

void Check(SECURITY_STATUS status, const char* operation) {
  if (status != ERROR_SUCCESS) {
    throw std::runtime_error(std::string(operation) + " failed (" +
                             std::to_string(static_cast<uint32_t>(status)) + ")");
  }
}

class CngObject {
 public:
  CngObject() = default;
  ~CngObject() { if (value) NCryptFreeObject(value); }
  CngObject(const CngObject&) = delete;
  CngObject& operator=(const CngObject&) = delete;
  NCRYPT_HANDLE value = 0;
};

DWORD ReadDword(NCRYPT_HANDLE object, const wchar_t* property) {
  DWORD value = 0;
  DWORD bytes = 0;
  Check(NCryptGetProperty(object, property, reinterpret_cast<PBYTE>(&value),
                         sizeof(value), &bytes, 0), "Read TPM property");
  if (bytes != sizeof(value)) throw std::runtime_error("Invalid TPM property");
  return value;
}

void OpenProvider(CngObject& provider) {
  Check(NCryptOpenStorageProvider(&provider.value, MS_PLATFORM_CRYPTO_PROVIDER, 0),
        "Open TPM provider");
  if (!(ReadDword(provider.value, NCRYPT_IMPL_TYPE_PROPERTY) & NCRYPT_IMPL_HARDWARE_FLAG)) {
    throw std::runtime_error("TPM provider is not hardware backed");
  }
}

void SetDword(NCRYPT_HANDLE key, const wchar_t* property, DWORD value) {
  Check(NCryptSetProperty(key, property, reinterpret_cast<PBYTE>(&value),
                         sizeof(value), 0), "Configure TPM key");
}

void ValidateWrappingKey(NCRYPT_KEY_HANDLE key) {
  if (ReadDword(key, NCRYPT_LENGTH_PROPERTY) != kRsaBits ||
      ReadDword(key, NCRYPT_EXPORT_POLICY_PROPERTY) != 0) {
    throw std::runtime_error("Unexpected TPM wrapping-key properties");
  }
}

void CreateWrappingKey(NCRYPT_PROV_HANDLE provider, CngObject& key) {
  Check(NCryptCreatePersistedKey(provider, &key.value, NCRYPT_RSA_ALGORITHM,
                                kWrappingKeyName, 0, 0), "Create TPM wrapping key");
  SetDword(key.value, NCRYPT_LENGTH_PROPERTY, kRsaBits);
  SetDword(key.value, NCRYPT_KEY_USAGE_PROPERTY, NCRYPT_ALLOW_DECRYPT_FLAG);
  Check(NCryptFinalizeKey(key.value, NCRYPT_SILENT_FLAG), "Persist TPM wrapping key");
}

void OpenOrCreateWrappingKey(NCRYPT_PROV_HANDLE provider, CngObject& key) {
  const auto status = NCryptOpenKey(provider, &key.value, kWrappingKeyName, 0,
                                   NCRYPT_SILENT_FLAG);
  if (status == NTE_BAD_KEYSET || status == NTE_NOT_FOUND) {
    CreateWrappingKey(provider, key);
  } else {
    Check(status, "Open TPM wrapping key");
  }
  ValidateWrappingKey(key.value);
}

std::vector<uint8_t> EncryptKey(NCRYPT_KEY_HANDLE key, const std::vector<uint8_t>& input) {
  BCRYPT_OAEP_PADDING_INFO padding{BCRYPT_SHA256_ALGORITHM, nullptr, 0};
  std::vector<uint8_t> output(kRsaBits / 8);
  DWORD written = 0;
  Check(NCryptEncrypt(key, const_cast<PBYTE>(input.data()),
                      static_cast<DWORD>(input.size()), &padding, output.data(),
                      static_cast<DWORD>(output.size()), &written,
                      NCRYPT_PAD_OAEP_FLAG | NCRYPT_SILENT_FLAG), "Wrap vault key");
  if (written != output.size()) throw std::runtime_error("Invalid wrapped-key length");
  return output;
}

std::vector<uint8_t> DecryptKey(NCRYPT_KEY_HANDLE key, const std::vector<uint8_t>& input) {
  BCRYPT_OAEP_PADDING_INFO padding{BCRYPT_SHA256_ALGORITHM, nullptr, 0};
  std::array<uint8_t, kRsaBits / 8> plaintext{};
  DWORD written = 0;
  const auto status = NCryptDecrypt(
      key, const_cast<PBYTE>(input.data() + kHeader.size()), kRsaBits / 8,
      &padding, plaintext.data(), static_cast<DWORD>(plaintext.size()), &written,
      NCRYPT_PAD_OAEP_FLAG | NCRYPT_SILENT_FLAG);
  std::vector<uint8_t> result;
  if (status == ERROR_SUCCESS && written == 32) {
    result.assign(plaintext.begin(), plaintext.begin() + written);
  }
  SecureZeroMemory(plaintext.data(), plaintext.size());
  Check(status, "Unwrap vault key");
  if (result.size() != 32) throw std::runtime_error("Invalid vault-key length");
  return result;
}

}

bool TpmKeyStore::IsAvailable() const {
  TPM_DEVICE_INFO info{};
  info.structVersion = TPM_VERSION_20;
  const auto status = Tbsi_GetDeviceInfo(sizeof(info), &info);
  if (status == static_cast<TBS_RESULT>(TBS_E_TPM_NOT_FOUND)) return false;
  if (status != TBS_SUCCESS) throw std::runtime_error("Cannot query TPM device");
  if (info.tpmVersion != TPM_VERSION_20) return false;
  CngObject provider;
  OpenProvider(provider);
  return true;
}

std::vector<uint8_t> TpmKeyStore::Protect(const std::vector<uint8_t>& vault_key) const {
  if (vault_key.size() != 32) throw std::invalid_argument("Expected a 32-byte vault key");
  if (!IsAvailable()) throw std::runtime_error("TPM 2.0 is unavailable");
  CngObject provider;
  OpenProvider(provider);
  CngObject key;
  OpenOrCreateWrappingKey(provider.value, key);
  const auto ciphertext = EncryptKey(key.value, vault_key);
  std::vector<uint8_t> result(kHeader.begin(), kHeader.end());
  result.insert(result.end(), ciphertext.begin(), ciphertext.end());
  return result;
}

std::vector<uint8_t> TpmKeyStore::Unprotect(const std::vector<uint8_t>& protected_key) const {
  if (protected_key.size() != kHeader.size() + kRsaBits / 8 ||
      !std::equal(kHeader.begin(), kHeader.end(), protected_key.begin())) {
    throw std::invalid_argument("Invalid Windows TPM protected key");
  }
  CngObject provider;
  OpenProvider(provider);
  CngObject key;
  Check(NCryptOpenKey(provider.value, &key.value, kWrappingKeyName, 0,
                      NCRYPT_SILENT_FLAG), "Open existing TPM wrapping key");
  ValidateWrappingKey(key.value);
  return DecryptKey(key.value, protected_key);
}

}
