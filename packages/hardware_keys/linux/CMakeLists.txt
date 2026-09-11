cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "hardware_keys")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "hardware_keys_plugin")

pkg_check_modules(TPM2 REQUIRED IMPORTED_TARGET tss2-esys tss2-mu tss2-tctildr)

list(APPEND PLUGIN_SOURCES
  "hardware_keys_plugin.cc"
  "tpm_context.cc"
  "tpm_sealed_blob.cc"
  "tpm_key_store.cc"
  "tpm_method_handler.cc"
)

add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::TPM2)

set(hardware_keys_bundled_libraries
  ""
  PARENT_SCOPE
)

if (${include_${PROJECT_NAME}_tests})
if(${CMAKE_VERSION} VERSION_LESS "3.11.0")
message("Unit tests require CMake 3.11.0 or later")
else()
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
  test/hardware_keys_plugin_test.cc
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter)
target_link_libraries(${TEST_RUNNER} PRIVATE PkgConfig::GTK)
target_link_libraries(${TEST_RUNNER} PRIVATE PkgConfig::TPM2)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)

include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})

endif()
endif()
