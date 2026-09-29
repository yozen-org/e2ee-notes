#include "tpm_key_store.h"

#include <algorithm>
#include <cstring>
#include <memory>
#include <stdexcept>

#include "tpm_context.h"
#include "tpm_sealed_blob.h"

namespace secure_keys {
namespace {

constexpr size_t kP256Bytes = 32;

void ClearBytes(void* data, size_t size) {
  volatile uint8_t* bytes = static_cast<volatile uint8_t*>(data);
  while (size--) *bytes++ = 0;
}

struct SensitiveInput {
  TPM2B_SENSITIVE_CREATE value{};
  ~SensitiveInput() { ClearBytes(&value, sizeof(value)); }
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

TPM2B_PUBLIC RecipientKeyTemplate() {
  TPM2B_PUBLIC result{};
  auto& area = result.publicArea;
  area.type = TPM2_ALG_ECC;
  area.nameAlg = TPM2_ALG_SHA256;
  area.objectAttributes = TPMA_OBJECT_SENSITIVEDATAORIGIN |
      TPMA_OBJECT_USERWITHAUTH | TPMA_OBJECT_DECRYPT | TPMA_OBJECT_NODA;
  auto& ecc = area.parameters.eccDetail;
  ecc.symmetric.algorithm = TPM2_ALG_NULL;
  ecc.scheme.scheme = TPM2_ALG_NULL;
  ecc.curveID = TPM2_ECC_NIST_P256;
  ecc.kdf.scheme = TPM2_ALG_NULL;
  area.unique.ecc.x.size = 0;
  area.unique.ecc.y.size = 0;
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

TpmSealedBlob CreateRecipientKeyObject(ESYS_CONTEXT* context, ESYS_TR primary,
                                       ESYS_TR session) {
  SensitiveInput input;
  const auto public_area = RecipientKeyTemplate();
  const TPM2B_DATA outside_info{};
  const TPML_PCR_SELECTION creation_pcr{};
  TPM2B_PRIVATE* private_area = nullptr;
  TPM2B_PUBLIC* public_area_out = nullptr;
  const auto status = Esys_Create(context, primary, session, ESYS_TR_NONE,
                                  ESYS_TR_NONE, &input.value, &public_area,
                                  &outside_info, &creation_pcr, &private_area,
                                  &public_area_out, nullptr, nullptr, nullptr);
  std::unique_ptr<TPM2B_PRIVATE, decltype(&Esys_Free)> private_owner(private_area, Esys_Free);
  std::unique_ptr<TPM2B_PUBLIC, decltype(&Esys_Free)> public_owner(public_area_out, Esys_Free);
  CheckTpm(status, "Create recipient key");
  return {*private_area, *public_area_out};
}

void CopyPadded(uint8_t* destination, const TPM2B_ECC_PARAMETER& source) {
  if (source.size > kP256Bytes) throw std::runtime_error("Invalid ECC coordinate size");
  std::memset(destination, 0, kP256Bytes);
  std::memcpy(destination + (kP256Bytes - source.size), source.buffer, source.size);
}

std::vector<uint8_t> PublicPoint(const TPM2B_PUBLIC& public_area) {
  if (public_area.publicArea.type != TPM2_ALG_ECC) {
    throw std::runtime_error("Recipient key is not an EC key");
  }
  const auto& point = public_area.publicArea.unique.ecc;
  std::vector<uint8_t> encoded(kP256Bytes * 2 + 1);
  encoded[0] = 0x04;
  CopyPadded(encoded.data() + 1, point.x);
  CopyPadded(encoded.data() + 1 + kP256Bytes, point.y);
  return encoded;
}

ESYS_TR LoadRecipientKey(ESYS_CONTEXT* context, const TpmSealedBlob& blob,
                         TpmObject& primary, TpmObject& object) {
  CheckTpm(Esys_Load(context, primary.value, ESYS_TR_PASSWORD, ESYS_TR_NONE,
                    ESYS_TR_NONE, &blob.private_area, &blob.public_area, &object.value),
           "Load recipient key");
  return object.value;
}

}  // namespace

RecipientKey TpmKeyStore::CreateRecipientKey() const {
  TpmObject primary(context_);
  CreateStoragePrimary(context_, primary);
  TpmObject session(context_);
  StartProtectedSession(context_, primary.value, TPMA_SESSION_DECRYPT, session);
  const auto blob = CreateRecipientKeyObject(context_, primary.value, session.value);
  return {blob.Encode(), PublicPoint(blob.public_area)};
}

std::vector<uint8_t> TpmKeyStore::OpenRecipientKey(
    const std::vector<uint8_t>& handle) const {
  const auto blob = TpmSealedBlob::Decode(handle);
  TpmObject primary(context_);
  CreateStoragePrimary(context_, primary);
  TpmObject object(context_);
  LoadRecipientKey(context_, blob, primary, object);
  return PublicPoint(blob.public_area);
}

std::vector<uint8_t> TpmKeyStore::SharedSecret(
    const std::vector<uint8_t>& handle,
    const std::vector<uint8_t>& peer_public_key) const {
  if (peer_public_key.size() != kP256Bytes * 2 + 1 || peer_public_key[0] != 0x04) {
    throw std::invalid_argument("Invalid X9.63 public key");
  }
  const auto blob = TpmSealedBlob::Decode(handle);
  TpmObject primary(context_);
  CreateStoragePrimary(context_, primary);
  TpmObject object(context_);
  const auto key = LoadRecipientKey(context_, blob, primary, object);

  TPM2B_ECC_POINT in_point{};
  in_point.size = static_cast<UINT16>(sizeof(in_point.point));
  in_point.point.x.size = static_cast<UINT16>(kP256Bytes);
  in_point.point.y.size = static_cast<UINT16>(kP256Bytes);
  std::memcpy(in_point.point.x.buffer, peer_public_key.data() + 1, kP256Bytes);
  std::memcpy(in_point.point.y.buffer, peer_public_key.data() + 1 + kP256Bytes, kP256Bytes);

  TpmObject session(context_);
  StartProtectedSession(context_, primary.value, TPMA_SESSION_ENCRYPT, session);
  TPM2B_ECC_POINT* out_point = nullptr;
  const auto status = Esys_ECDH_ZGen(context_, key, session.value, ESYS_TR_NONE,
                                     ESYS_TR_NONE, &in_point, &out_point);
  std::unique_ptr<TPM2B_ECC_POINT, decltype(&Esys_Free)> owner(out_point, Esys_Free);
  CheckTpm(status, "Compute ECDH shared secret");

  std::vector<uint8_t> shared(kP256Bytes);
  CopyPadded(shared.data(), out_point->point.x);
  return shared;
}

}
