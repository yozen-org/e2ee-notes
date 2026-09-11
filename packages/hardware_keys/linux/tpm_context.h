#pragma once

#include <tss2/tss2_esys.h>
#include <tss2/tss2_tctildr.h>

namespace hardware_keys {

void CheckTpm(TSS2_RC status, const char* operation);

class TpmContext {
 public:
  explicit TpmContext(const char* transport);
  ~TpmContext();
  TpmContext(const TpmContext&) = delete;
  TpmContext& operator=(const TpmContext&) = delete;
  ESYS_CONTEXT* get() const { return context_; }
  static bool IsDeviceAvailable();

 private:
  TSS2_TCTI_CONTEXT* transport_ = nullptr;
  ESYS_CONTEXT* context_ = nullptr;
};

class TpmObject {
 public:
  explicit TpmObject(ESYS_CONTEXT* context) : context_(context) {}
  ~TpmObject();
  TpmObject(const TpmObject&) = delete;
  TpmObject& operator=(const TpmObject&) = delete;
  ESYS_TR value = ESYS_TR_NONE;

 private:
  ESYS_CONTEXT* context_;
};

}
