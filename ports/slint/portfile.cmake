# Slint's C++ runtime (api/cpp) is built from the Rust workspace via Corrosion:
# the CMake project drives cargo for the slint-cpp crate (cdylib/staticlib),
# generates the C++ headers with cbindgen (as a build dependency) and installs
# the slint-compiler tool for ahead-of-time .slint compilation.

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO slint-ui/slint
    REF "v${VERSION}"
    SHA512 e515249390aaed5b3bc6d3ef41222910ef7e36cf2937472aae28e18e6480d33ca63d9d0c7f41bc7895ac8a5f96bbbd3147af2f54cfa3a52367ba52c7ec50ebea
    HEAD_REF master
)

# Static linkage is not supported: upstream installs no static system-library
# link interface for the Rust staticlib, and the skia feature has no prebuilt
# skia-binaries for static-CRT triplets (a source build would additionally
# require LLVM/clang-cl).
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    message(FATAL_ERROR "slint does not support static linkage; use a dynamic triplet such as x64-windows.")
endif()

vcpkg_cargo_setup()

# The renderer features map 1:1 to SLINT_FEATURE_* CMake options and from there
# to cargo features of the slint-cpp crate. Upstream defaults femtovg+software
# on desktop platforms, so every renderer is passed explicitly.
vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        software     SLINT_FEATURE_RENDERER_SOFTWARE
        femtovg      SLINT_FEATURE_RENDERER_FEMTOVG
        skia         SLINT_FEATURE_RENDERER_SKIA
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/api/cpp"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DSLINT_BUILD_TESTING=OFF
        "-DRust_ROOT=${CURRENT_HOST_INSTALLED_DIR}/tools/rust"
    MAYBE_UNUSED_VARIABLES
        SLINT_BUILD_TESTING
)

# rustc always links the release UCRT (/MD) on msvc targets, also for cargo's
# debug profile, so vcpkg's CRT linkage check does not apply to the Rust part.
set(VCPKG_POLICY_SKIP_CRT_LINKAGE_CHECK enabled)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME Slint CONFIG_PATH lib/cmake/Slint)

# Upstream installs the cdylib with TYPE LIB, i.e. slint_cpp.dll ends up in lib/
# (Unix habit). vcpkg requires DLLs in bin/ for applocal deployment.
if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    foreach(_pkg_dir IN ITEMS "${CURRENT_PACKAGES_DIR}" "${CURRENT_PACKAGES_DIR}/debug")
        if(EXISTS "${_pkg_dir}/lib/slint_cpp.dll")
            file(MAKE_DIRECTORY "${_pkg_dir}/bin")
            file(RENAME "${_pkg_dir}/lib/slint_cpp.dll" "${_pkg_dir}/bin/slint_cpp.dll")
        endif()
    endforeach()
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
vcpkg_copy_pdbs()

vcpkg_install_copyright(
    FILE_LIST
        "${SOURCE_PATH}/LICENSES/GPL-3.0-only.txt"
        "${SOURCE_PATH}/LICENSES/LicenseRef-Slint-Royalty-free-2.0.md"
        "${SOURCE_PATH}/LICENSES/LicenseRef-Slint-Software-3.0.md"
)
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
