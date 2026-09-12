#pragma once

#include <cstdint>
#include <vector>

namespace secure_keys {

class TpmKeyStore {
 public:
  bool IsAvailable() const;
  std::vector<uint8_t> Protect(const std::vector<uint8_t>& vault_key) const;
  std::vector<uint8_t> Unprotect(const std::vector<uint8_t>& protected_key) const;
};

}
