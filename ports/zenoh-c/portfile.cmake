# zenoh-c is a CMake project that drives cargo itself: it generates Cargo.toml from
# Cargo.toml.in and invokes `cargo build` to produce zenohc.dll / libzenohc.a plus
# the headers in its build directory.

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO eclipse-zenoh/zenoh-c
    REF "${VERSION}"
    SHA512 92b17cb164c32715c423e83579dc5b855df42e681ca1f6c3b582a7c18a218449573c6e4975f6f63e50831911c854e192898394ce151d1ff8a3f15fc0af625f36
    HEAD_REF main
)

# zenoh-c features are exposed as vcpkg features. Cargo feature names use
# underscores (plus the odd 'transport_unixsock-stream'), vcpkg feature names
# use dashes; the map below translates. Requesting any feature switches cargo
# to --no-default-features, so the vcpkg feature list is the exact feature set
# (see README "Zenoh features support"); with no feature requested the upstream
# cargo default set is built.
set(_feature_map
    shared-memory=shared-memory
    unstable-api=unstable
    stats=stats
    auth-pubkey=auth_pubkey
    auth-usrpwd=auth_usrpwd
    transport-multilink=transport_multilink
    transport-compression=transport_compression
    transport-quic=transport_quic
    transport-serial=transport_serial
    transport-unixpipe=transport_unixpipe
    transport-tcp=transport_tcp
    transport-tls=transport_tls
    transport-udp=transport_udp
    transport-unixsock-stream=transport_unixsock-stream
    transport-ws=transport_ws
    transport-vsock=transport_vsock
    transport-quic-datagram=transport_quic_datagram
)

set(_cargo_features "")
foreach(_map_entry IN LISTS _feature_map)
    string(REPLACE "=" ";" _pair "${_map_entry}")
    list(GET _pair 0 _vcpkg_feature)
    list(GET _pair 1 _cargo_feature)
    if("${_vcpkg_feature}" IN_LIST FEATURES)
        list(APPEND _cargo_features "${_cargo_feature}")
    endif()
endforeach()

set(_cargo_flags "")
if(_cargo_features)
    list(JOIN _cargo_features "," _cargo_features)
    list(APPEND _cargo_flags --no-default-features "--features=${_cargo_features}")
endif()

vcpkg_cargo_setup()

# zenoh-c 1.9.x invokes plain `cargo` resolved from PATH, so the toolchain bin
# directory prepended to PATH by vcpkg_cargo_setup() selects the vcpkg-provided
# cargo for the build. Newer zenoh-c versions additionally honor
# ENV{CARGO_COMMAND}; environment variables set in the portfile are not
# reliably visible to the configure process, so they are also injected there
# via CMAKE_PROJECT_TOP_LEVEL_INCLUDES (included by zenoh-c's project() call).
set(_cargo_env_file "${CURRENT_BUILDTREES_DIR}/zenoh-c-cargo-env.cmake")
configure_file("${CMAKE_CURRENT_LIST_DIR}/cargo-env.cmake.in" "${_cargo_env_file}" @ONLY)
set(ENV{CARGO_COMMAND} "${VCPKG_CARGO_EXECUTABLE}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        "-DZENOHC_CARGO_FLAGS=${_cargo_flags}"
        "-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=${_cargo_env_file}"
        -DZENOHC_BUILD_TESTS_WITH_CXX=FALSE
    MAYBE_UNUSED_VARIABLES
        ZENOHC_BUILD_TESTS_WITH_CXX
)

# Note: rustc always links the *release* UCRT (/MD) on msvc targets, also for cargo's
# debug profile. vcpkg's CRT linkage check for the debug build is therefore not
# applicable to the Rust-produced part of this port.
set(VCPKG_POLICY_SKIP_CRT_LINKAGE_CHECK enabled)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME zenohc CONFIG_PATH lib/cmake/zenohc)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
vcpkg_copy_pdbs()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE" "${SOURCE_PATH}/NOTICE.md")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
