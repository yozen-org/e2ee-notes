#include "tpm_key_store.h"

#include <algorithm>
#include <memory>
#include <stdexcept>

#include "tpm_context.h"
#include "tpm_sealed_blob.h"

namespace secure_keys {
namespace {

void ClearBytes(void* data, size_t size) {
  volatile uint8_t* bytes = static_cast<volatile uint8_t*>(data);
  while (size--) *bytes++ = 0;
}

struct SensitiveInput {
  TPM2B_SENSITIVE_CREATE value{};
  ~SensitiveInput() { ClearBytes(&value, sizeof(value)); }
};

struct SensitiveOutputDeleter {
  void operator()(TPM2B_SENSITIVE_DATA* data) const {
    if (data) ClearBytes(data, sizeof(*data));
    Esys_Free(data);
  }
};

TPM2B_PUBLIC StoragePrimaryTemplate() {
  TPM2B_PUBLIC result{};
  auto& area = result.publicArea;
  area.type = TPM2_ALG_RSA;
  area.nameAlg = TPM2_ALG_SHA256;
  area.objectAttributes = TPMA_OBJECT_FIXEDTPM | TPMA_OBJECT_FIXEDPARENT |
      TPMA_OBJECT_SENSITIVEDATAORIGIN | TPMA_OBJECT_USERWITHAUTH |
      TPMA_OBJECT_RESTRICTED | TPMA_OBJECT_DECRYPT | TPMA_OBJECT_NODA;
  auto& rsa = area.parameters.rsaDetail;
  rsa.symmetric.algorithm = TPM2_ALG_AES;
  rsa.symmetric.keyBits.aes = 128;
  rsa.symmetric.mode.aes = TPM2_ALG_CFB;
  rsa.scheme.scheme = TPM2_ALG_NULL;
  rsa.keyBits = 2048;
  return result;
}

TPM2B_PUBLIC SealedKeyTemplate() {
  TPM2B_PUBLIC result{};
  result.publicArea.type = TPM2_ALG_KEYEDHASH;
  result.publicArea.nameAlg = TPM2_ALG_SHA256;
  result.publicArea.objectAttributes = TPMA_OBJECT_FIXEDTPM | TPMA_OBJECT_FIXEDPARENT |
      TPMA_OBJECT_USERWITHAUTH | TPMA_OBJECT_NODA;
  result.publicArea.parameters.keyedHashDetail.scheme.scheme = TPM2_ALG_NULL;
  return result;
}

void CreateStoragePrimary(ESYS_CONTEXT* context, TpmObject& primary) {
  const TPM2B_SENSITIVE_CREATE sensitive{};
  const auto public_area = StoragePrimaryTemplate();
  const TPM2B_DATA outside_info{};
  const TPML_PCR_SELECTION creation_pcr{};
  CheckTpm(Esys_CreatePrimary(context, ESYS_TR_RH_OWNER, ESYS_TR_PASSWORD,
                             ESYS_TR_NONE, ESYS_TR_NONE, &sensitive, &public_area,
                             &outside_info, &creation_pcr, &primary.value,
                             nullptr, nullptr, nullptr, nullptr), "Create storage primary");
}

void StartProtectedSession(ESYS_CONTEXT* context, ESYS_TR primary,
                           TPMA_SESSION protection, TpmObject& session) {
  TPMT_SYM_DEF symmetric{};
  symmetric.algorithm = TPM2_ALG_AES;
  symmetric.keyBits.aes = 128;
  symmetric.mode.aes = TPM2_ALG_CFB;
  CheckTpm(Esys_StartAuthSession(context, primary, ESYS_TR_NONE, ESYS_TR_NONE,
                                ESYS_TR_NONE, ESYS_TR_NONE, nullptr, TPM2_SE_HMAC,
                                &symmetric, TPM2_ALG_SHA256, &session.value),
           "Start encrypted TPM session");
  CheckTpm(Esys_TRSess_SetAttributes(context, session.value,
                                    protection | TPMA_SESSION_CONTINUESESSION, 0xff),
           "Configure encrypted TPM session");
}

TpmSealedBlob SealKey(ESYS_CONTEXT* context, ESYS_TR primary, ESYS_TR session,
                      const std::vector<uint8_t>& vault_key) {
  SensitiveInput input;
  input.value.sensitive.data.size = static_cast<UINT16>(vault_key.size());
  std::copy(vault_key.begin(), vault_key.end(), input.value.sensitive.data.buffer);
  const auto public_area = SealedKeyTemplate();
  const TPM2B_DATA outside_info{};
  const TPML_PCR_SELECTION creation_pcr{};
  TPM2B_PRIVATE* sealed_private = nullptr;
  TPM2B_PUBLIC* sealed_public = nullptr;
  const auto status = Esys_Create(context, primary, session, ESYS_TR_NONE,
                                  ESYS_TR_NONE, &input.value, &public_area,
                                  &outside_info, &creation_pcr, &sealed_private,
                                  &sealed_public, nullptr, nullptr, nullptr);
  std::unique_ptr<TPM2B_PRIVATE, decltype(&Esys_Free)> private_owner(sealed_private, Esys_Free);
  std::unique_ptr<TPM2B_PUBLIC, decltype(&Esys_Free)> public_owner(sealed_public, Esys_Free);
  CheckTpm(status, "Seal vault key");
  return {*sealed_private, *sealed_public};
}

std::vector<uint8_t> UnsealKey(ESYS_CONTEXT* context, ESYS_TR object, ESYS_TR session) {
  TPM2B_SENSITIVE_DATA* plaintext = nullptr;
  const auto status = Esys_Unseal(context, object, session, ESYS_TR_NONE,
                                  ESYS_TR_NONE, &plaintext);
  std::unique_ptr<TPM2B_SENSITIVE_DATA, SensitiveOutputDeleter> owner(plaintext);
  CheckTpm(status, "Unseal vault key");
  if (plaintext->size != 32) throw std::runtime_error("Invalid vault-key length");
  return {plaintext->buffer, plaintext->buffer + plaintext->size};
}

}

std::vector<uint8_t> TpmKeyStore::Protect(const std::vector<uint8_t>& vault_key) const {
  if (vault_key.size() != 32) throw std::invalid_argument("Expected a 32-byte vault key");
  TpmObject primary(context_);
  CreateStoragePrimary(context_, primary);
  TpmObject session(context_);
  StartProtectedSession(context_, primary.value, TPMA_SESSION_DECRYPT, session);
  return SealKey(context_, primary.value, session.value, vault_key).Encode();
}

std::vector<uint8_t> TpmKeyStore::Unprotect(const std::vector<uint8_t>& protected_key) const {
  const auto blob = TpmSealedBlob::Decode(protected_key);
  TpmObject primary(context_);
  CreateStoragePrimary(context_, primary);
  TpmObject sealed(context_);
  CheckTpm(Esys_Load(context_, primary.value, ESYS_TR_PASSWORD, ESYS_TR_NONE,
                    ESYS_TR_NONE, &blob.private_area, &blob.public_area, &sealed.value),
           "Load sealed vault key");
  TpmObject session(context_);
  StartProtectedSession(context_, primary.value, TPMA_SESSION_ENCRYPT, session);
  return UnsealKey(context_, sealed.value, session.value);
}

}
