#pragma once

#include <tss2/tss2_tpm2_types.h>

#include <cstdint>
#include <vector>

namespace secure_keys {

struct TpmSealedBlob {
  TPM2B_PRIVATE private_area{};
  TPM2B_PUBLIC public_area{};

  std::vector<uint8_t> Encode() const;
  static TpmSealedBlob Decode(const std::vector<uint8_t>& encoded);
};

}
