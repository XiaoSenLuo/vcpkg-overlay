
set(VCPKG_TARGET_ARCHITECTURE arm)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)

set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# set(VCPKG_C_FLAGS "")
# set(VCPKG_CXX_FLAGS "")

if(NOT DEFINED ENV{VCPKG_ROOT})
    message(FATAL_ERROR "not defined environment variable: VCPKG_ROOT")
endif()

if (NOT DEFINED VCPKG_CHAINLOAD_TOOLCHAIN_FILE)
    set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE $ENV{VCPKG_ROOT}/scripts/toolchains/amd-linux.cmake)
endif()
