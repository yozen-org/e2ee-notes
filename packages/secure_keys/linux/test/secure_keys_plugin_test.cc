#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include "include/secure_keys/secure_keys_plugin.h"
#include "secure_keys_plugin_private.h"

namespace secure_keys {
namespace test {

TEST(SecureKeysPlugin, GetPlatformVersion) {
  g_autoptr(FlMethodResponse) response = get_platform_version();
  ASSERT_NE(response, nullptr);
  ASSERT_TRUE(FL_IS_METHOD_SUCCESS_RESPONSE(response));
  FlValue* result = fl_method_success_response_get_result(
      FL_METHOD_SUCCESS_RESPONSE(response));
  ASSERT_EQ(fl_value_get_type(result), FL_VALUE_TYPE_STRING);

  EXPECT_THAT(fl_value_get_string(result), testing::StartsWith("Linux "));
}

}
}
