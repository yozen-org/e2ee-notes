#pragma once

#include <tss2/tss2_esys.h>

#include <cstdint>
#include <vector>

namespace secure_keys {

class TpmKeyStore {
 public:
  explicit TpmKeyStore(ESYS_CONTEXT* context) : context_(context) {}
  std::vector<uint8_t> Protect(const std::vector<uint8_t>& vault_key) const;
  std::vector<uint8_t> Unprotect(const std::vector<uint8_t>& protected_key) const;

 private:
  ESYS_CONTEXT* context_;
};

}
