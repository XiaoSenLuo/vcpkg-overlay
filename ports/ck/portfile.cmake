vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO concurrencykit/ck
    REF "${VERSION}"
    SHA512 c3a93a8bbdab2c81ccbfe8f38a17677b912bc157c231c960330cb130e93c35e3aab6b2fd1695d0ea28dbe3e12297851f1b96ef1ee21ca4e4c0065c91b83f51c3
    HEAD_REF master
    PATCHES
        0001-fix-cross-compiler-detect.patch
        0002-fix-header-file-detect.patch
)

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "static" DISABLE_SHARED)
string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" DISABLE_STATIC)

vcpkg_list(SET OPTIONS)
if(DISABLE_SHARED)
    list(APPEND OPTIONS --disable-shared)
endif()
if(DISABLE_STATIC)
    list(APPEND OPTIONS --disable-static)
endif()

# 交叉编译：强制 platform + 真正的交叉编译器，避免 configure 用 uname / 跑测试程序检测到 host
if(VCPKG_CROSSCOMPILING)
    # 获取 vcpkg / toolchain 真正使用的编译器
    vcpkg_cmake_get_vars(cmake_vars_file)
    include("${cmake_vars_file}")

    set(CK_PLATFORM "")
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(CK_PLATFORM "x86_64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        set(CK_PLATFORM "x86")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        set(CK_PLATFORM "arm")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64" OR VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64ec")
        set(CK_PLATFORM "aarch64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "s390x")
        set(CK_PLATFORM "s390x")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "ppc64le")
        set(CK_PLATFORM "ppc64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "riscv32")
        set(CK_PLATFORM "riscv32")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "riscv64")
        set(CK_PLATFORM "riscv64")
    else()
        set(CK_PLATFORM "unknown")
    endif()
    
    list(APPEND OPTIONS
        --platform=${CK_PLATFORM}
        # --profile=${CK_PLATFORM}   
        "CC=${VCPKG_DETECTED_CMAKE_C_COMPILER}"
    )

    if(VCPKG_DETECTED_CMAKE_AR)
        list(APPEND OPTIONS "AR=${VCPKG_DETECTED_CMAKE_AR}")
    endif()
    if(VCPKG_DETECTED_CMAKE_LINKER)
        list(APPEND OPTIONS "LD=${VCPKG_DETECTED_CMAKE_LINKER}")
    endif()
endif()

# ck 的 configure 不是标准 autotools
# vcpkg_make_install 使用 DESTDIR，因此 --prefix 必须用相对路径
vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_DEFAULT_OPTIONS
    OPTIONS
        ${OPTIONS}
    OPTIONS_RELEASE
        --prefix=
        --libdir=lib
        --includedir=include
        --mandir=share/ck
        "CFLAGS=${VCPKG_COMBINED_C_FLAGS_RELEASE}"
    OPTIONS_DEBUG
        --prefix=
        --libdir=debug/lib
        --includedir=include
        --mandir=share/ck
        "CFLAGS=${VCPKG_COMBINED_C_FLAGS_DEBUG}"
)

vcpkg_make_install()

vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

# 安装独立的 CMake 配置与 usage 文件
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-ck-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-${PORT}"
)
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
