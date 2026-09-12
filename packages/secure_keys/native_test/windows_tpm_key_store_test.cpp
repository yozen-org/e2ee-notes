#include <iostream>
#include <string>
#include <vector>

#include "test_checks.h"
#include "tpm_key_store.h"

int main(int argc, char** argv) {
  try {
    const secure_keys::TpmKeyStore store;
    RequireFailure([&] { store.Protect(std::vector<uint8_t>(31)); });
    RequireFailure([&] { store.Unprotect({}); });
    RequireFailure([&] { store.Unprotect(std::vector<uint8_t>(260)); });
    if (argc > 1 && std::string(argv[1]) == "--tpm") {
      Require(store.IsAvailable(), "TPM 2.0 required for integration test");
      const std::vector<uint8_t> key(32, 0x37);
      const auto blob = store.Protect(key);
      Require(secure_keys::TpmKeyStore().Unprotect(blob) == key, "TPM roundtrip failed");
      auto changed = blob;
      changed.back() ^= 1;
      RequireFailure([&] { store.Unprotect(changed); });
      auto wrong_version = blob;
      wrong_version[3] = 2;
      RequireFailure([&] { store.Unprotect(wrong_version); });
      const auto other = store.Protect(std::vector<uint8_t>(32, 0x49));
      Require(store.Unprotect(blob) == key, "New vault replaced existing wrapping key");
      Require(other != blob, "Different keys produced identical blobs");
    }
    std::cout << "TPM tests passed" << std::endl;
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << std::endl;
    return 1;
  }
}
