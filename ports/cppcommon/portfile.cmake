# Upstream pulls its dependencies (fmt, vld) with the 'gil' tool as git
# subdirectory clones under modules/ and builds them via add_subdirectory().
# That mechanism does not work inside vcpkg, therefore the portfile installs
# a self-contained CMakeLists.txt which consumes vcpkg's fmt package instead.

# Upstream builds plain libraries and defines no dllexport macros. MSVC needs
# explicit exports to produce a usable DLL, so keep the static library there.
# GCC and Clang (Linux, macOS, MinGW) export all symbols by default and can
# build shared libraries out of the box.
if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_MINGW)
    set(VCPKG_LIBRARY_LINKAGE static)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO chronoxor/CppCommon
    REF 9eba9ba6034a2b408a50fb84593adb8730e5e954
    SHA512 058f7b461d647185e4a40ce325f6bb03c5c53ea17102b81ff32c99a5e36dfc8b8c91931cb0928bf1ff60bfb64c2ef7f3a4acdcbb756bfb4e69468bca84b8a6cf
    HEAD_REF main
    PATCHES
        patches/0001-guard-vld-include.patch
        patches/0002-portable-muldiv64.patch
        patches/0003-include-sys-time.patch
)

file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" "${CMAKE_CURRENT_LIST_DIR}/cppcommon-config.cmake.in"
    DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
