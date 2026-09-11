#pragma once

#include <flutter_linux/flutter_linux.h>

FlMethodResponse* handle_tpm_method(const gchar* method, FlValue* arguments);
