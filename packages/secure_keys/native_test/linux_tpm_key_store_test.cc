#include <iostream>
#include <string>
#include <vector>

#include "test_checks.h"
#include "tpm_context.h"
#include "tpm_key_store.h"
#include "tpm_sealed_blob.h"

using secure_keys::TpmContext;
using secure_keys::TpmKeyStore;
using secure_keys::TpmSealedBlob;

void CheckInvalidBlobs() {
  for (const auto& bytes : std::vector<std::vector<uint8_t>>{
      {}, {'E', 'T', 'L', 1}, {'E', 'T', 'W', 1}, std::vector<uint8_t>(8193)}) {
    RequireFailure([&] { TpmSealedBlob::Decode(bytes); });
  }
  const TpmKeyStore disconnected(nullptr);
  RequireFailure([&] { disconnected.Protect(std::vector<uint8_t>(31)); });
}

void StartEmulator(ESYS_CONTEXT* context) {
  const auto status = Esys_Startup(context, TPM2_SU_CLEAR);
  if (status != TPM2_RC_INITIALIZE) secure_keys::CheckTpm(status, "Start emulator");
}

std::vector<uint8_t> ProtectInNewContext(const char* transport, const std::vector<uint8_t>& key) {
  TpmContext context(transport);
  StartEmulator(context.get());
  return TpmKeyStore(context.get()).Protect(key);
}

void CheckProtectedKey(const char* transport, const std::vector<uint8_t>& key,
                       const std::vector<uint8_t>& blob) {
  TpmContext context(transport);
  StartEmulator(context.get());
  const TpmKeyStore store(context.get());
  Require(store.Unprotect(blob) == key, "Key changed after reopening TPM context");
  auto changed = TpmSealedBlob::Decode(blob);
  changed.private_area.buffer[changed.private_area.size - 1] ^= 1;
  RequireFailure([&] { store.Unprotect(changed.Encode()); });
  auto trailing = blob;
  trailing.push_back(0);
  RequireFailure([&] { store.Unprotect(trailing); });
  auto wrong_version = blob;
  wrong_version[3] = 2;
  RequireFailure([&] { store.Unprotect(wrong_version); });
}

int main(int argc, char** argv) {
  try {
    CheckInvalidBlobs();
    if (argc > 1) {
      const std::vector<uint8_t> key(32, 0x37);
      const auto blob = ProtectInNewContext(argv[1], key);
      CheckProtectedKey(argv[1], key, blob);
      const auto other_blob = ProtectInNewContext(argv[1], std::vector<uint8_t>(32, 0x49));
      Require(blob != other_blob, "Independent keys produced identical blobs");
      CheckProtectedKey(argv[1], key, blob);
      if (argc > 2) {
        TpmContext other(argv[2]);
        StartEmulator(other.get());
        RequireFailure([&] { TpmKeyStore(other.get()).Unprotect(blob); });
      }
    }
    std::cout << "TPM tests passed" << std::endl;
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << std::endl;
    return 1;
  }
}
