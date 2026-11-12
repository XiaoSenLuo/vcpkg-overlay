vcpkg_minimum_required(VERSION 2022-10-12) # for ${VERSION}

if(VCPKG_CROSSCOMPILING)
    message(FATAL_ERROR "This is a host only port!")
endif()

set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

set(RUST_VERSION "${VERSION}")

# Map the vcpkg host triplet to the Rust host triple of the official distribution archives.
if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_MINGW)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(VCPKG_RUST_HOST_TRIPLE x86_64-pc-windows-msvc)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        set(VCPKG_RUST_HOST_TRIPLE i686-pc-windows-msvc)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(VCPKG_RUST_HOST_TRIPLE aarch64-pc-windows-msvc)
    endif()
elseif(VCPKG_TARGET_IS_OSX)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(VCPKG_RUST_HOST_TRIPLE x86_64-apple-darwin)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(VCPKG_RUST_HOST_TRIPLE aarch64-apple-darwin)
    endif()
elseif(VCPKG_TARGET_IS_LINUX)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(VCPKG_RUST_HOST_TRIPLE x86_64-unknown-linux-gnu)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        set(VCPKG_RUST_HOST_TRIPLE i686-unknown-linux-gnu)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(VCPKG_RUST_HOST_TRIPLE aarch64-unknown-linux-gnu)
    endif()
endif()

if(NOT DEFINED VCPKG_RUST_HOST_TRIPLE)
    message(FATAL_ERROR "Unsupported host triplet '${HOST_TRIPLET}' for '${PORT}'. \
Please extend the host triple mapping in ${CMAKE_CURRENT_LIST_FILE} and add the SHA512 of \
https://static.rust-lang.org/dist/rust-${RUST_VERSION}-<triple>.tar.gz to the table below.")
endif()

# SHA512 of https://static.rust-lang.org/dist/rust-${RUST_VERSION}-<triple>.tar.gz
# Note: only the linux-gnu entries are refreshed for RUST_VERSION; the windows and
# darwin hashes below are stale and must be recomputed before building on those hosts.
set(RUST_DIST_SHA512_x86_64-pc-windows-msvc "83aa1ff11eae567920ae97a77ed0e9f3c95112c743923cf9408c65793704068c64f2f6f3aca93dc76de80d4e016027d69a5b0ccad3738de4688ae7e915055510")
set(RUST_DIST_SHA512_aarch64-pc-windows-msvc "616f665e92e0886cd8939783259570be13c182523b2d4158b794036243c2e5a6c04349280d4efa089e7866ae87902cbe2f7ffc6c4b295d793f06e3f099975e32")
set(RUST_DIST_SHA512_x86_64-unknown-linux-gnu "9a3d49b1749a7cb829189ec314c3280671e32a15cdbc49705c4271e229d2463843a917cdbe7fed4e85b977a8429ff7292c0c11fded481aad8d8a0a38ea434ec7")
set(RUST_DIST_SHA512_aarch64-unknown-linux-gnu "02f7bdffad5c97c6594586719bf7807e5bd1d4a01705050cf4f53f3bb9dfc0648881f233d6770433cf93ad859e87aa0fb69edfe4efceab7432d15227e8efe532")
set(RUST_DIST_SHA512_x86_64-apple-darwin "db1a63c559047f7fb3025dd60a42d8d7bfd8a3eb5d91f4252ca5ff18317c0c3ab002cd1d3ab818fa42019fd0300d29a47c0ef28b99309d7624f39f2531c91188")
set(RUST_DIST_SHA512_aarch64-apple-darwin "9bb59c9b47cbef360fdc43067f21386240b5f8261c32d9c1fc4408e49f11a7afbd3461698f129acc050eab4a0cc1d186bd3cab1e8b5dd109f0e8f45ea1297a07")

# SHA512 of https://static.rust-lang.org/dist/rust-std-${RUST_VERSION}-<triple>.tar.gz
set(RUST_STD_SHA512_x86_64-pc-windows-msvc "c5963b1bc777c83d392728d7856d699ee4777dcf635b45a5a1dd85722f3592d7233de19a2f4238c88589143cf72bee2d4a15ef1f0c10d5f1aabb3cb25e2ca8dc")
set(RUST_STD_SHA512_aarch64-pc-windows-msvc "41a8e88d34c9c9606878153cf7683486c7ebd7290752caa95d869de2489e89d9bdbe4e829944d983948b48cd247fdd0beefe6049320b84226207bee6d38db704")
set(RUST_STD_SHA512_x86_64-unknown-linux-gnu "887cba295344102ce3a7f8f4f8b65ce9bbe141a0076e64a2aa6f96b8d04436d9a9eb08006883b32bd4f10ab80f6658f99a8f98ddecf4f1537d1949096c7cbcf3")
set(RUST_STD_SHA512_aarch64-unknown-linux-gnu "f61ae7d68a0d829b2d5c2f1932f9b630cfd35597b999b289bd22f37b88e1a05501ef1e94b49a8f25469ecec0246a0379f070ba19fe7cc8ba71a4dd8a798b801e")
set(RUST_STD_SHA512_x86_64-apple-darwin "4c634bec2ffa5dc4d261a1e40f02a34a407f9dd6e2891d17b3d0f691873d0699ad13016b14df4bb91d2abcc85028f4a685bdcdb0da788e5583cf23258d990a25")
set(RUST_STD_SHA512_aarch64-apple-darwin "a0715a66e5987f0f76a7eff0de2faa0b2b1b453c54065c79dc24551760b259192854207b6b92d29fd2ad19ec3d15f9b0892c85144e30b13ebc87b61b0fee3b9c")
set(RUST_STD_SHA512_arm64ec-pc-windows-msvc "bd4986a1f8b2a89f5a73a1454b5c9e8f97d9c60d71ca1de8186b28bd243009e9c6025bd89434cd0c74aeb903eebb61cc43601716c18fdc62386211068a1e1044")
set(RUST_STD_SHA512_i686-pc-windows-msvc "33267fb2d5fd4adcc874238c259fc4dd245b76cc82cbaaed12ac66e9cad2b1890df7895395df61eb9673c26094fea7903b9712518b634966e7751a56fd771937")
set(RUST_STD_SHA512_armv7-unknown-linux-gnueabihf "b8d3d2a757bc453ecf0b68f5306647acdc6de9952f807be07d669fc3cb40c31e5ff1645aafd276a2afebf2c50bd89f6baccb755dc5f5b2f686a0d09021c618e2")
set(RUST_STD_SHA512_i686-unknown-linux-gnu "aa8a9a1d1df3e336329a989799379048e37b870b456c8ca90731961985d48ed8e197887c2d0d9c9bd90f12a692e1910e7357ec9c6996b95ce7205e5e9791fe31")

set(TOOLCHAIN_DIR "${CURRENT_PACKAGES_DIR}/tools/rust")

function(extract_dist_archive out_var archive)
    set(_extract_dir "${CURRENT_BUILDTREES_DIR}/extract/${ARGV2}")
    file(REMOVE_RECURSE "${_extract_dir}")
    file(MAKE_DIRECTORY "${_extract_dir}")
    vcpkg_execute_in_download_mode(
        COMMAND "${CMAKE_COMMAND}" -E tar xzf "${archive}"
        WORKING_DIRECTORY "${_extract_dir}"
    )
    set(${out_var} "${_extract_dir}" PARENT_SCOPE)
endfunction()

# 1. The host toolchain archive bundles rustc, cargo and the host rust-std.
vcpkg_download_distfile(HOST_ARCHIVE
    URLS "https://static.rust-lang.org/dist/rust-${RUST_VERSION}-${VCPKG_RUST_HOST_TRIPLE}.tar.gz"
    SHA512 "${RUST_DIST_SHA512_${VCPKG_RUST_HOST_TRIPLE}}"
    FILENAME "rust-${RUST_VERSION}-${VCPKG_RUST_HOST_TRIPLE}.tar.gz"
)
extract_dist_archive(HOST_EXTRACT_DIR "${HOST_ARCHIVE}" host)
set(HOST_ROOT_DIR "${HOST_EXTRACT_DIR}/rust-${RUST_VERSION}-${VCPKG_RUST_HOST_TRIPLE}")

file(MAKE_DIRECTORY "${TOOLCHAIN_DIR}")
file(COPY "${HOST_ROOT_DIR}/rustc/bin/" DESTINATION "${TOOLCHAIN_DIR}/bin")
file(COPY "${HOST_ROOT_DIR}/rustc/lib/" DESTINATION "${TOOLCHAIN_DIR}/lib")
file(COPY "${HOST_ROOT_DIR}/cargo/bin/" DESTINATION "${TOOLCHAIN_DIR}/bin")
file(COPY "${HOST_ROOT_DIR}/rust-std-${VCPKG_RUST_HOST_TRIPLE}/lib/rustlib/" DESTINATION "${TOOLCHAIN_DIR}/lib/rustlib")

# 2. rustup-target-add equivalent: preinstall the rust-std of every Rust target that
#    the vcpkg triplets of the host platform family can select, so that native and
#    same-family cross builds (e.g. x64-windows host building arm64-windows or
#    x86-windows targets) work out of the box. Targets of other families (mingw,
#    android, ios, ...) map in vcpkg-cargo but their std is not bundled; the helper
#    reports the missing component with the exact distfile to add.
if(VCPKG_RUST_HOST_TRIPLE MATCHES "-pc-windows-msvc$")
    set(VCPKG_RUST_TARGET_STDS
        x86_64-pc-windows-msvc
        aarch64-pc-windows-msvc
        i686-pc-windows-msvc
        arm64ec-pc-windows-msvc)
elseif(VCPKG_RUST_HOST_TRIPLE MATCHES "-unknown-linux-gnu$")
    set(VCPKG_RUST_TARGET_STDS
        x86_64-unknown-linux-gnu
        aarch64-unknown-linux-gnu
        i686-unknown-linux-gnu
        armv7-unknown-linux-gnueabihf)
elseif(VCPKG_RUST_HOST_TRIPLE MATCHES "-apple-darwin$")
    set(VCPKG_RUST_TARGET_STDS
        x86_64-apple-darwin
        aarch64-apple-darwin)
endif()
list(REMOVE_DUPLICATES VCPKG_RUST_TARGET_STDS)
list(REMOVE_ITEM VCPKG_RUST_TARGET_STDS "${VCPKG_RUST_HOST_TRIPLE}") # host std already installed
foreach(_std_triple IN LISTS VCPKG_RUST_TARGET_STDS)
    vcpkg_download_distfile(STD_ARCHIVE_${_std_triple}
        URLS "https://static.rust-lang.org/dist/rust-std-${RUST_VERSION}-${_std_triple}.tar.gz"
        SHA512 "${RUST_STD_SHA512_${_std_triple}}"
        FILENAME "rust-std-${RUST_VERSION}-${_std_triple}.tar.gz"
    )
    extract_dist_archive(STD_EXTRACT_DIR "${STD_ARCHIVE_${_std_triple}}" "std-${_std_triple}")
    set(STD_ROOT_DIR "${STD_EXTRACT_DIR}/rust-std-${RUST_VERSION}-${_std_triple}")
    file(COPY "${STD_ROOT_DIR}/rust-std-${_std_triple}/lib/rustlib/" DESTINATION "${TOOLCHAIN_DIR}/lib/rustlib")
endforeach()

# Debug information of the toolchain binaries is not useful inside a vcpkg installation.
file(GLOB_RECURSE _pdbs "${TOOLCHAIN_DIR}/*.pdb")
if(_pdbs)
    file(REMOVE ${_pdbs})
endif()

# Some distributions of rust-std ship an empty self-contained directory, which is
# not representable in the binary cache.
file(GLOB _empty_self_contained "${TOOLCHAIN_DIR}/lib/rustlib/*/lib/self-contained")
foreach(_dir IN LISTS _empty_self_contained)
    file(GLOB _content "${_dir}/*")
    if(NOT _content)
        file(REMOVE_RECURSE "${_dir}")
    endif()
endforeach()

# Smoke test: make sure the installed toolchain is self-contained and runnable.
vcpkg_execute_required_process(
    COMMAND "${TOOLCHAIN_DIR}/bin/rustc${VCPKG_HOST_EXECUTABLE_SUFFIX}" --version
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME rustc-version-${HOST_TRIPLET}
)
vcpkg_execute_required_process(
    COMMAND "${TOOLCHAIN_DIR}/bin/cargo${VCPKG_HOST_EXECUTABLE_SUFFIX}" --version
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME cargo-version-${HOST_TRIPLET}
)

vcpkg_install_copyright(FILE_LIST "${HOST_ROOT_DIR}/LICENSE-MIT" "${HOST_ROOT_DIR}/LICENSE-APACHE")
