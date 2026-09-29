#include "tpm_key_store.h"

#include <windows.h>
#include <bcrypt.h>
#include <ncrypt.h>
#include <tbs.h>

#include <algorithm>
#include <cstring>
#include <stdexcept>
#include <string>
#include <vector>

namespace secure_keys {
namespace {

constexpr size_t kP256Bytes = 32;

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

std::wstring NewKeyName() {
  GUID guid{};
  Check(CoCreateGuid(&guid), "Generate key name");
  wchar_t buffer[40];
  swprintf_s(buffer, L"recipient-%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x",
             guid.Data1, guid.Data2, guid.Data3, guid.Data4[0], guid.Data4[1],
             guid.Data4[2], guid.Data4[3], guid.Data4[4], guid.Data4[5],
             guid.Data4[6], guid.Data4[7]);
  return std::wstring(buffer);
}

void CreateRecipientKey(NCRYPT_PROV_HANDLE provider, const std::wstring& name,
                        CngObject& key) {
  Check(NCryptCreatePersistedKey(provider, &key.value, NCRYPT_ECDH_P256_ALGORITHM,
                                 name.c_str(), 0, 0), "Create TPM recipient key");
  Check(NCryptFinalizeKey(key.value, NCRYPT_SILENT_FLAG), "Persist TPM recipient key");
}

void OpenRecipientKeyByName(NCRYPT_PROV_HANDLE provider, const std::wstring& name,
                            CngObject& key) {
  Check(NCryptOpenKey(provider, &key.value, name.c_str(), 0, NCRYPT_SILENT_FLAG),
        "Open TPM recipient key");
}

// Exports the public key as a 65-byte X9.63 uncompressed point.
std::vector<uint8_t> ExportPublicKey(NCRYPT_KEY_HANDLE key) {
  DWORD size = 0;
  Check(NCryptExportKey(key, nullptr, BCRYPT_ECCPUBLIC_BLOB, nullptr, nullptr, 0,
                        &size, 0), "Measure recipient public key");
  std::vector<uint8_t> blob(size);
  Check(NCryptExportKey(key, nullptr, BCRYPT_ECCPUBLIC_BLOB, nullptr, blob.data(),
                        size, &size, 0), "Export recipient public key");
  const auto* header = reinterpret_cast<const BCRYPT_ECCPUBLIC_BLOB*>(blob.data());
  const auto* x = blob.data() + sizeof(BCRYPT_ECCPUBLIC_BLOB);
  const auto* y = x + header->cbKey;
  std::vector<uint8_t> encoded(kP256Bytes * 2 + 1);
  encoded[0] = 0x04;
  std::reverse_copy(x, x + kP256Bytes, encoded.begin() + 1);
  std::reverse_copy(y, y + kP256Bytes, encoded.begin() + 1 + kP256Bytes);
  return encoded;
}

// Imports a 65-byte X9.63 point as a transient peer key.
void ImportPeerPublicKey(NCRYPT_PROV_HANDLE provider,
                         const std::vector<uint8_t>& x963, CngObject& peer) {
  if (x963.size() != kP256Bytes * 2 + 1 || x963[0] != 0x04) {
    throw std::invalid_argument("Invalid X9.63 public key");
  }
  std::vector<uint8_t> blob(sizeof(BCRYPT_ECCPUBLIC_BLOB) + kP256Bytes * 2);
  auto* header = reinterpret_cast<BCRYPT_ECCPUBLIC_BLOB*>(blob.data());
  header->dwMagic = BCRYPT_ECDH_PUBLIC_P256_MAGIC;
  header->cbKey = kP256Bytes;
  std::reverse_copy(x963.begin() + 1, x963.begin() + 1 + kP256Bytes,
                    blob.begin() + sizeof(BCRYPT_ECCPUBLIC_BLOB));
  std::reverse_copy(x963.begin() + 1 + kP256Bytes, x963.end(),
                    blob.begin() + sizeof(BCRYPT_ECCPUBLIC_BLOB) + kP256Bytes);
  Check(NCryptImportKey(provider, nullptr, BCRYPT_ECCPUBLIC_BLOB, nullptr,
                        &peer.value, blob.data(), static_cast<DWORD>(blob.size()), 0),
        "Import peer public key");
}

// Computes the ECDH shared secret (the X coordinate, big-endian, left-padded).
std::vector<uint8_t> ComputeSharedSecret(NCRYPT_KEY_HANDLE key,
                                         NCRYPT_KEY_HANDLE peer) {
  NCRYPT_SECRET_HANDLE secret = 0;
  Check(NCryptSecretAgreement(key, peer, &secret, 0), "Compute ECDH shared secret");
  std::vector<uint8_t> buffer(kP256Bytes);
  DWORD size = 0;
  const auto status = NCryptDeriveKey(secret, BCRYPT_KDF_RAW_SECRET, nullptr,
                                      buffer.data(), kP256Bytes, &size, 0);
  NCryptFreeObject(secret);
  Check(status, "Derive ECDH shared secret");
  if (size == 0 || size > kP256Bytes) {
    throw std::runtime_error("Invalid shared secret length");
  }
  std::vector<uint8_t> shared(kP256Bytes);
  std::memcpy(shared.data() + (kP256Bytes - size), buffer.data(), size);
  return shared;
}

std::wstring NameFromHandle(const std::vector<uint8_t>& handle) {
  if (handle.size() % sizeof(wchar_t) != 0 || handle.empty()) {
    throw std::invalid_argument("Invalid key handle");
  }
  return std::wstring(reinterpret_cast<const wchar_t*>(handle.data()),
                      handle.size() / sizeof(wchar_t));
}

std::vector<uint8_t> HandleFromName(const std::wstring& name) {
  const auto* bytes = reinterpret_cast<const uint8_t*>(name.data());
  return std::vector<uint8_t>(bytes, bytes + name.size() * sizeof(wchar_t));
}

}  // namespace

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

RecipientKey TpmKeyStore::CreateRecipientKey() const {
  CngObject provider;
  OpenProvider(provider);
  const auto name = NewKeyName();
  CngObject key;
  CreateRecipientKey(provider.value, name, key);
  return {HandleFromName(name), ExportPublicKey(key.value)};
}

std::vector<uint8_t> TpmKeyStore::OpenRecipientKey(
    const std::vector<uint8_t>& handle) const {
  CngObject provider;
  OpenProvider(provider);
  CngObject key;
  OpenRecipientKeyByName(provider.value, NameFromHandle(handle), key);
  return ExportPublicKey(key.value);
}

std::vector<uint8_t> TpmKeyStore::SharedSecret(
    const std::vector<uint8_t>& handle,
    const std::vector<uint8_t>& peer_public_key) const {
  CngObject provider;
  OpenProvider(provider);
  CngObject key;
  OpenRecipientKeyByName(provider.value, NameFromHandle(handle), key);
  CngObject peer;
  ImportPeerPublicKey(provider.value, peer_public_key, peer);
  return ComputeSharedSecret(key.value, peer.value);
}

}
