# zenoh-cpp is a header-only library that requires the zenoh-c backend to be
# installed. Its build system only needs to install headers and the CMake package
# configuration files.

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO eclipse-zenoh/zenoh-cpp
    REF "${VERSION}"
    SHA512 5282d990577c5898137079413324ff6c605d03f9a020f1900f7efdd7babf252b6097ea33990ff887010e4c49ecf78405322fc4c3799be9879b981e203aab5f1e
    HEAD_REF main
    PATCHES
        0001-find-zenohc-dependency.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DZENOHCXX_ZENOHC=ON
        -DZENOHCXX_ZENOHPICO=OFF
        -DZENOHCXX_ENABLE_TESTS=OFF
        -DZENOHCXX_ENABLE_EXAMPLES=OFF
        -DZENOHCXX_EXAMPLES_PROTOBUF=OFF
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME zenohcxx CONFIG_PATH lib/cmake/zenohcxx)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
