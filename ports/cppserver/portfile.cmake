# Upstream pulls its dependencies (asio, CppCommon) with the 'gil' tool as
# git subdirectory clones under modules/ and builds them via add_subdirectory().
# That mechanism does not work inside vcpkg, therefore the portfile installs a
# self-contained CMakeLists.txt which consumes vcpkg's asio/cppcommon/OpenSSL
# packages instead.

# Upstream builds plain libraries and defines no dllexport macros. MSVC needs
# explicit exports to produce a usable DLL, so keep the static library there.
# GCC and Clang (Linux, macOS, MinGW) export all symbols by default and can
# build shared libraries out of the box.
if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_MINGW)
    set(VCPKG_LIBRARY_LINKAGE static)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO chronoxor/CppServer
    REF 00caf5cf93d5656c598649ce77ba7981eb170779
    SHA512 2936adb7a70278f022058a17740ebc680252b19a01c36356c2510296cbcba7aece208bf4f9640a9c6c9248727c9705a276e13ab4e43bcc7d606011166f53fd4b
    HEAD_REF master
    PATCHES
        patches/0001-disable-asio-separate-compilation.patch
)

file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" "${CMAKE_CURRENT_LIST_DIR}/cppserver-config.cmake.in"
    DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
