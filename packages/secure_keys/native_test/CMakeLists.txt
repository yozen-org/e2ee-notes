cmake_minimum_required(VERSION 3.14)
project(tpm_key_store_tests LANGUAGES CXX)

enable_testing()
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(WIN32)
  add_executable(tpm_key_store_test
    windows_tpm_key_store_test.cpp
    ../windows/tpm_key_store.cpp
  )
  target_include_directories(tpm_key_store_test PRIVATE ../windows)
  target_link_libraries(tpm_key_store_test PRIVATE ncrypt tbs)
  target_compile_options(tpm_key_store_test PRIVATE /W4 /WX /EHsc)
else()
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(TPM2 REQUIRED IMPORTED_TARGET tss2-esys tss2-mu tss2-tctildr)
  add_executable(tpm_key_store_test
    linux_tpm_key_store_test.cc
    ../linux/tpm_context.cc
    ../linux/tpm_key_store.cc
    ../linux/tpm_sealed_blob.cc
  )
  target_include_directories(tpm_key_store_test PRIVATE ../linux)
  target_link_libraries(tpm_key_store_test PRIVATE PkgConfig::TPM2)
  target_compile_options(tpm_key_store_test PRIVATE -Wall -Wextra -Werror)
endif()

add_test(NAME tpm_key_store COMMAND tpm_key_store_test)
