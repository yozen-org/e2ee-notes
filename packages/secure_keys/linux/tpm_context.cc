#include "tpm_context.h"

#include <sys/stat.h>

#include <cerrno>
#include <stdexcept>
#include <string>

namespace secure_keys {

void CheckTpm(TSS2_RC status, const char* operation) {
  if (status != TSS2_RC_SUCCESS) {
    throw std::runtime_error(std::string(operation) + " failed (" +
                             std::to_string(status) + ")");
  }
}

TpmContext::TpmContext(const char* transport) {
  CheckTpm(Tss2_TctiLdr_Initialize(transport, &transport_), "Open TPM transport");
  const auto status = Esys_Initialize(&context_, transport_, nullptr);
  if (status != TSS2_RC_SUCCESS) {
    Tss2_TctiLdr_Finalize(&transport_);
    CheckTpm(status, "Initialize TPM context");
  }
}

TpmContext::~TpmContext() {
  Esys_Finalize(&context_);
  Tss2_TctiLdr_Finalize(&transport_);
}

bool TpmContext::IsDeviceAvailable() {
  struct stat device{};
  if (stat("/dev/tpmrm0", &device) != 0) {
    if (errno == ENOENT) return false;
    throw std::runtime_error("Cannot inspect /dev/tpmrm0");
  }
  if (!S_ISCHR(device.st_mode)) throw std::runtime_error("Invalid TPM device");
  TpmContext context("device:/dev/tpmrm0");
  TPMS_CAPABILITY_DATA* capability = nullptr;
  TPMI_YES_NO more = TPM2_NO;
  CheckTpm(Esys_GetCapability(context.get(), ESYS_TR_NONE, ESYS_TR_NONE,
                             ESYS_TR_NONE, TPM2_CAP_TPM_PROPERTIES,
                             TPM2_PT_FAMILY_INDICATOR, 1, &more, &capability),
           "Query TPM version");
  const bool supported = capability &&
      capability->capability == TPM2_CAP_TPM_PROPERTIES &&
      capability->data.tpmProperties.count == 1 &&
      capability->data.tpmProperties.tpmProperty[0].property == TPM2_PT_FAMILY_INDICATOR &&
      capability->data.tpmProperties.tpmProperty[0].value == 0x322e3000;
  Esys_Free(capability);
  return supported;
}

TpmObject::~TpmObject() {
  if (value != ESYS_TR_NONE) Esys_FlushContext(context_, value);
}

}
