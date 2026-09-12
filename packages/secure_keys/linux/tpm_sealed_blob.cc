#include "tpm_sealed_blob.h"

#include <tss2/tss2_mu.h>

#include <algorithm>
#include <array>
#include <stdexcept>

#include "tpm_context.h"

namespace secure_keys {
namespace {
constexpr std::array<uint8_t, 4> kHeader = {'E', 'T', 'L', 1};
}

std::vector<uint8_t> TpmSealedBlob::Encode() const {
  std::vector<uint8_t> encoded(8192);
  std::copy(kHeader.begin(), kHeader.end(), encoded.begin());
  size_t offset = kHeader.size();
  CheckTpm(Tss2_MU_TPM2B_PRIVATE_Marshal(&private_area, encoded.data(), encoded.size(), &offset),
           "Encode sealed private area");
  CheckTpm(Tss2_MU_TPM2B_PUBLIC_Marshal(&public_area, encoded.data(), encoded.size(), &offset),
           "Encode sealed public area");
  encoded.resize(offset);
  return encoded;
}

TpmSealedBlob TpmSealedBlob::Decode(const std::vector<uint8_t>& encoded) {
  if (encoded.size() < kHeader.size() || encoded.size() > 8192 ||
      !std::equal(kHeader.begin(), kHeader.end(), encoded.begin())) {
    throw std::invalid_argument("Invalid Linux TPM protected key");
  }
  TpmSealedBlob blob;
  size_t offset = kHeader.size();
  CheckTpm(Tss2_MU_TPM2B_PRIVATE_Unmarshal(encoded.data(), encoded.size(), &offset, &blob.private_area),
           "Decode sealed private area");
  CheckTpm(Tss2_MU_TPM2B_PUBLIC_Unmarshal(encoded.data(), encoded.size(), &offset, &blob.public_area),
           "Decode sealed public area");
  if (offset != encoded.size() || blob.public_area.publicArea.type != TPM2_ALG_KEYEDHASH) {
    throw std::invalid_argument("Invalid sealed-key structure");
  }
  return blob;
}

}
