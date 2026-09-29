#pragma once

#include <cstdint>
#include <vector>

namespace secure_keys {

struct RecipientKey {
  std::vector<uint8_t> handle;       // persisted key name
  std::vector<uint8_t> public_key;   // X9.63 uncompressed P-256 point
};

class TpmKeyStore {
 public:
  bool IsAvailable() const;
  RecipientKey CreateRecipientKey() const;
  std::vector<uint8_t> OpenRecipientKey(
      const std::vector<uint8_t>& handle) const;
  std::vector<uint8_t> SharedSecret(
      const std::vector<uint8_t>& handle,
      const std::vector<uint8_t>& peer_public_key) const;
};

}
