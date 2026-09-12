cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "secure_keys")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "secure_keys_plugin")

list(APPEND PLUGIN_SOURCES
  "secure_keys_plugin.cpp"
  "secure_keys_plugin.h"
  "tpm_key_store.cpp"
)

add_library(${PLUGIN_NAME} SHARED
  "include/secure_keys/secure_keys_plugin_c_api.h"
  "secure_keys_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})
get_target_property(plugin_definitions ${PLUGIN_NAME} COMPILE_DEFINITIONS)
list(REMOVE_ITEM plugin_definitions "_HAS_EXCEPTIONS=0")
set_property(TARGET ${PLUGIN_NAME} PROPERTY COMPILE_DEFINITIONS "${plugin_definitions}")

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
target_link_libraries(${PLUGIN_NAME} PRIVATE ncrypt tbs)

set(secure_keys_bundled_libraries
  ""
  PARENT_SCOPE
)

if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/release-1.11.0.zip
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

add_executable(${TEST_RUNNER}
  test/secure_keys_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
get_target_property(test_definitions ${TEST_RUNNER} COMPILE_DEFINITIONS)
list(REMOVE_ITEM test_definitions "_HAS_EXCEPTIONS=0")
set_property(TARGET ${TEST_RUNNER} PROPERTY COMPILE_DEFINITIONS "${test_definitions}")
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
target_link_libraries(${TEST_RUNNER} PRIVATE ncrypt tbs)
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
