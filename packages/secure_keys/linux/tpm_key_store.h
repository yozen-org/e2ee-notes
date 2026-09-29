#pragma once

#include <tss2/tss2_esys.h>

#include <cstdint>
#include <vector>

namespace secure_keys {

struct RecipientKey {
  std::vector<uint8_t> handle;       // encoded private+public blob
  std::vector<uint8_t> public_key;   // X9.63 uncompressed P-256 point
};

class TpmKeyStore {
 public:
  explicit TpmKeyStore(ESYS_CONTEXT* context) : context_(context) {}

  RecipientKey CreateRecipientKey() const;
  std::vector<uint8_t> OpenRecipientKey(
      const std::vector<uint8_t>& handle) const;
  std::vector<uint8_t> SharedSecret(
      const std::vector<uint8_t>& handle,
      const std::vector<uint8_t>& peer_public_key) const;

 private:
  ESYS_CONTEXT* context_;
};

}
