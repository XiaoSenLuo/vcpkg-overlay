# vcpkg_cargo_target_triple(OUT_VAR)
#
# Sets ${OUT_VAR} to the Rust target triple matching the current vcpkg target
# triplet. The mapping is derived from the vcpkg triplet space (official and
# community triplets) and every returned triple is a valid `rustup target list`
# entry. Triplets without a Rust equivalent leave ${OUT_VAR} unset and fail with
# an explanation.
#
# Notes:
#   * iOS/tvOS/watchOS/visionOS simulator triplets are detected via
#     VCPKG_OSX_SYSROOT and mapped to the corresponding *-sim targets.
#   * armv6 Android (ANDROID_ABI=armeabi) maps to arm-linux-androideabi,
#     armeabi-v7a maps to armv7-linux-androideabi.
function(vcpkg_cargo_target_triple OUT_VAR)
    set(_triple "")

    if(VCPKG_TARGET_IS_UWP OR VCPKG_TARGET_IS_XBOX)
        # No Rust std distribution exists for WindowsStore/Xbox targets.
    elseif(VCPKG_TARGET_IS_MINGW)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(_triple x86_64-pc-windows-gnu)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
            set(_triple i686-pc-windows-gnu)
        endif()
    elseif(VCPKG_TARGET_IS_WINDOWS)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(_triple x86_64-pc-windows-msvc)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
            set(_triple i686-pc-windows-msvc)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(_triple aarch64-pc-windows-msvc)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64ec")
            set(_triple arm64ec-pc-windows-msvc)
        endif()
    elseif(VCPKG_TARGET_IS_OSX)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(_triple x86_64-apple-darwin)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(_triple aarch64-apple-darwin)
        endif()
    elseif(VCPKG_TARGET_IS_IOS OR VCPKG_TARGET_IS_TVOS OR VCPKG_TARGET_IS_WATCHOS OR VCPKG_TARGET_IS_VISIONOS)
        if(VCPKG_TARGET_IS_IOS)
            set(_device aarch64-apple-ios)
            set(_device_x64 x86_64-apple-ios)
            set(_sim aarch64-apple-ios-sim)
        elseif(VCPKG_TARGET_IS_TVOS)
            set(_device aarch64-apple-tvos)
            set(_sim aarch64-apple-tvos-sim)
        elseif(VCPKG_TARGET_IS_WATCHOS)
            set(_device aarch64-apple-watchos)
            set(_sim aarch64-apple-watchos-sim)
        else()
            set(_device aarch64-apple-visionos)
            set(_sim aarch64-apple-visionos-sim)
        endif()
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(_triple "${_device_x64}")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            if(VCPKG_OSX_SYSROOT MATCHES "simulator")
                set(_triple "${_sim}")
            else()
                set(_triple "${_device}")
            endif()
        endif()
    elseif(VCPKG_TARGET_IS_ANDROID)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(_triple aarch64-linux-android)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(_triple x86_64-linux-android)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
            set(_triple i686-linux-android)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
            if(VCPKG_CMAKE_CONFIGURE_OPTIONS MATCHES "ANDROID_ABI=armeabi($|;| )")
                set(_triple arm-linux-androideabi)
            else()
                set(_triple armv7-linux-androideabi)
            endif()
        endif()
    elseif(VCPKG_TARGET_IS_OHOS)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(_triple aarch64-unknown-linux-ohos)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
            set(_triple armv7-unknown-linux-ohos)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(_triple x86_64-unknown-linux-ohos)
        endif()
    elseif(VCPKG_TARGET_IS_EMSCRIPTEN)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "wasm32")
            set(_triple wasm32-unknown-emscripten)
        endif()
    elseif(VCPKG_TARGET_IS_FREEBSD)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(_triple x86_64-unknown-freebsd)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(_triple aarch64-unknown-freebsd)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
            set(_triple i686-unknown-freebsd)
        endif()
    elseif(VCPKG_TARGET_IS_NETBSD)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(_triple x86_64-unknown-netbsd)
        endif()
    elseif(VCPKG_TARGET_IS_SOLARIS)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(_triple x86_64-pc-solaris)
        endif()
    elseif(VCPKG_TARGET_IS_LINUX)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(_triple x86_64-unknown-linux-gnu)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
            set(_triple i686-unknown-linux-gnu)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(_triple aarch64-unknown-linux-gnu)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
            set(_triple armv7-unknown-linux-gnueabihf)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "riscv64")
            set(_triple riscv64gc-unknown-linux-gnu)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "ppc64le")
            set(_triple powerpc64le-unknown-linux-gnu)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "s390x")
            set(_triple s390x-unknown-linux-gnu)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "loongarch64")
            set(_triple loongarch64-unknown-linux-gnu)
        endif()
    endif()

    if(_triple STREQUAL "")
        message(FATAL_ERROR "The vcpkg triplet '${TARGET_TRIPLET}' has no equivalent \
Rust target (no matching entry in \`rustup target list\`). Extend \
vcpkg_cargo_target_triple() in ${CMAKE_CURRENT_LIST_FILE} if a mapping exists.")
    endif()
    set(${OUT_VAR} "${_triple}" PARENT_SCOPE)
endfunction()

# vcpkg_cargo_setup()
#
# Locates the Rust toolchain (installed by the `vcpkg-tool-rust` host port by default,
# with a fallback to a system-wide installation) and prepares the environment for
# subsequent cargo invocations:
#
#   * PATH is prepended with the toolchain binary directory (build scripts frequently
#     invoke plain `cargo` or `rustc`),
#   * CARGO_HOME is pointed at a download cache shared between all cargo ports,
#     laid out as downloads/tools/cargo-<cargo-version>-<host-platform> following
#     the vcpkg tools directory convention,
#   * CARGO_BUILD_TARGET is always set to the Rust target mapped from the current
#     vcpkg triplet - for native as well as cross builds - so that cargo output
#     locations (target/<triple>/<cfg>) are deterministic. This is the standalone
#     equivalent of selecting the target with `rustup target add` / `--target`.
#   * When the mapped target differs from the toolchain host triple, the required
#     target std library is verified to be part of the toolchain, mirroring
#     `rustup target add <target>`.
#   * For cross builds, HOST_CC/HOST_CXX are pointed at a host compiler (unless
#     already set): build-dependencies and their build scripts run on the host and
#     cc-rs prefers HOST_CC over a plain, target-oriented CC for host compiles.
#   * For cross builds, CARGO_TARGET_<triple>_LINKER is set from CC (unless already
#     set): rustc ignores CC for the final link step and would otherwise link the
#     target artifacts with the host compiler.
#   * For native builds, a CC/CXX that does not match the cargo target architecture
#     (a cross SDK environment sourced in the invoking shell) is replaced by the
#     host compiler, so cc-rs does not drive a cross compiler with host arguments.
#
# The function exports the following variables to the caller:
#   VCPKG_CARGO_EXECUTABLE, VCPKG_RUSTC_EXECUTABLE,
#   VCPKG_RUST_HOST_TRIPLE, VCPKG_RUST_TARGET_TRIPLE, VCPKG_CARGO_VERSION
function(vcpkg_cargo_setup)
    if(DEFINED VCPKG_CARGO_EXECUTABLE AND DEFINED VCPKG_RUSTC_EXECUTABLE)
        return() # already set up
    endif()

    set(_toolchain_dir "${CURRENT_HOST_INSTALLED_DIR}/tools/rust")
    set(_cargo "${_toolchain_dir}/bin/cargo${VCPKG_HOST_EXECUTABLE_SUFFIX}")
    set(_rustc "${_toolchain_dir}/bin/rustc${VCPKG_HOST_EXECUTABLE_SUFFIX}")

    if(NOT EXISTS "${_cargo}")
        # Fall back to a system installation of Rust (e.g. rustup).
        find_program(_system_cargo cargo)
        if(NOT _system_cargo)
            message(FATAL_ERROR "Could not find a Rust toolchain. \
Install the host port 'vcpkg-tool-rust' (dependency of 'vcpkg-cargo'), or make cargo available on PATH.")
        endif()
        message(STATUS "Using system Rust toolchain: ${_system_cargo}")
        cmake_path(GET _system_cargo PARENT_PATH _cargo_bin_dir)
        set(_cargo "${_system_cargo}")
        set(_rustc "${_cargo_bin_dir}/rustc${VCPKG_HOST_EXECUTABLE_SUFFIX}")
        set(_toolchain_dir "")
    endif()

    if(CMAKE_HOST_WIN32)
        set(_path_sep ";")
        set(_cargo_platform "windows")
    elseif(CMAKE_HOST_APPLE)
        set(_path_sep ":")
        set(_cargo_platform "osx")
    else()
        set(_path_sep ":")
        set(_cargo_platform "linux")
    endif()
    cmake_path(GET _cargo PARENT_PATH _cargo_bin_dir)
    set(ENV{PATH} "${_cargo_bin_dir}${_path_sep}$ENV{PATH}")
    set(ENV{RUSTC} "${_rustc}")

    # Query the toolchain version and host triple once.
    execute_process(
        COMMAND "${_cargo}" --version
        OUTPUT_VARIABLE _cargo_version_output
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" _cargo_version "${_cargo_version_output}")
    execute_process(
        COMMAND "${_rustc}" -vV
        OUTPUT_VARIABLE _rustc_vv_output
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    string(REGEX MATCH "host:[ \t]*[A-Za-z0-9_-]+" _rust_host_line "${_rustc_vv_output}")
    string(REGEX REPLACE "^host:[ \t]*" "" _rust_host_triple "${_rust_host_line}")

    # Use a cache shared between all cargo ports, named like the other tools in
    # downloads/tools (e.g. cargo-1.93.0-windows). This must be unconditional: a
    # CARGO_HOME inherited from e.g. a rustup installation would mix the vcpkg
    # builds into the user's registry and vice versa.
    set(_cargo_home "${DOWNLOADS}/tools/cargo-${_cargo_version}-${_cargo_platform}")
    file(MAKE_DIRECTORY "${_cargo_home}")
    set(ENV{CARGO_HOME} "${_cargo_home}")

    # The vcpkg triplet is the single source of truth for the Rust target,
    # for native and cross builds alike.
    vcpkg_cargo_target_triple(_target_triple)
    set(ENV{CARGO_BUILD_TARGET} "${_target_triple}")

    # Equivalent of `rustup target add <target>`: make sure the toolchain carries
    # the std library of the requested target.
    if(NOT "${_target_triple}" STREQUAL "${_rust_host_triple}"
       AND _toolchain_dir
       AND NOT EXISTS "${_toolchain_dir}/lib/rustlib/${_target_triple}/lib")
        message(FATAL_ERROR "The Rust toolchain of 'vcpkg-tool-rust' (host: ${_rust_host_triple}) \
does not provide the std library for the Rust target '${_target_triple}' required by the vcpkg \
triplet '${TARGET_TRIPLET}'. Add the component from \
https://static.rust-lang.org/dist/rust-std-${_cargo_version}-${_target_triple}.tar.gz \
to the 'vcpkg-tool-rust' port (SHA512 + host family target list).")
    endif()

    if(NOT "${_target_triple}" STREQUAL "${_rust_host_triple}")
        # Cross build. Build scripts and build-dependencies are compiled for the
        # host, where cc-rs falls back to the plain CC of the cross SDK environment
        # (the target compiler) unless a host compiler is pinned via HOST_CC.
        if(NOT DEFINED ENV{HOST_CC})
            find_program(_host_cc NAMES cc gcc clang)
            if(_host_cc)
                set(ENV{HOST_CC} "${_host_cc}")
            endif()
        endif()
        if(NOT DEFINED ENV{HOST_CXX})
            find_program(_host_cxx NAMES c++ g++ clang++)
            if(_host_cxx)
                set(ENV{HOST_CXX} "${_host_cxx}")
            endif()
        endif()

        # rustc does not honor CC for linking; select the target compiler as the
        # linker of the cargo target. CARGO_TARGET_<triple>_LINKER takes an
        # executable only, so the remaining CC tokens (sysroot, -mcpu, ...) are
        # forwarded as linker arguments via the per-target RUSTFLAGS.
        string(REPLACE "-" "_" _target_linker_var "CARGO_TARGET_${_target_triple}_LINKER")
        string(TOUPPER "${_target_linker_var}" _target_linker_var)
        string(REPLACE "-" "_" _target_rustflags_var "CARGO_TARGET_${_target_triple}_RUSTFLAGS")
        string(TOUPPER "${_target_rustflags_var}" _target_rustflags_var)
        if(NOT DEFINED ENV{${_target_linker_var}} AND DEFINED ENV{CC})
            separate_arguments(_cc NATIVE_COMMAND "$ENV{CC}")
            list(GET _cc 0 _cc_program)
            list(POP_FRONT _cc)
            set(ENV{${_target_linker_var}} "${_cc_program}")
            if(_cc)
                list(TRANSFORM _cc PREPEND "-Clink-arg=")
                list(JOIN _cc " " _link_args)
                set(ENV{${_target_rustflags_var}} "${_link_args} $ENV{RUSTFLAGS}")
            endif()
        endif()
    endif()

    if("${_target_triple}" STREQUAL "${_rust_host_triple}" AND DEFINED ENV{CC})
        # Native build. A cross SDK environment sourced in the invoking shell
        # (e.g. an OE environment-setup script) leaves CC/CXX pointing at the
        # target cross compiler, which cc-rs would then drive with host
        # arguments (e.g. -m64 for an x86_64 host). Detect the architecture
        # mismatch via -dumpmachine and pin host compilers instead.
        separate_arguments(_native_cc NATIVE_COMMAND "$ENV{CC}")
        list(GET _native_cc 0 _native_cc_program)
        set(_native_cc_dumpmachine "")
        execute_process(
            COMMAND "${_native_cc_program}" -dumpmachine
            OUTPUT_VARIABLE _native_cc_dumpmachine
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        set(_native_cc_arch "${_native_cc_dumpmachine}")
        string(REGEX MATCH "^[^-]+" _native_cc_arch "${_native_cc_arch}")
        set(_expected_arch "${_target_triple}")
        string(REGEX MATCH "^[^-]+" _expected_arch "${_expected_arch}")
        if(_expected_arch MATCHES "^arm")
            set(_expected_arch "arm")
        endif()
        if(_native_cc_arch AND NOT "${_native_cc_arch}" STREQUAL "${_expected_arch}")
            find_program(_host_cc NAMES cc gcc clang)
            find_program(_host_cxx NAMES c++ g++ clang++)
            if(_host_cc)
                message(STATUS "CC '${_native_cc_program}' targets '${_native_cc_arch}' but the cargo \
target is '${_target_triple}'; using host compiler '${_host_cc}' for the native cargo build")
                set(ENV{CC} "${_host_cc}")
                set(ENV{HOST_CC} "${_host_cc}")
            endif()
            if(_host_cxx)
                set(ENV{CXX} "${_host_cxx}")
                set(ENV{HOST_CXX} "${_host_cxx}")
            endif()
        endif()
    endif()

    message(STATUS "Using cargo: ${_cargo}")
    message(STATUS "Rust host triple: ${_rust_host_triple}")
    message(STATUS "Rust target triple (from triplet ${TARGET_TRIPLET}): ${_target_triple}")

    set(VCPKG_CARGO_EXECUTABLE "${_cargo}" PARENT_SCOPE)
    set(VCPKG_RUSTC_EXECUTABLE "${_rustc}" PARENT_SCOPE)
    set(VCPKG_RUST_HOST_TRIPLE "${_rust_host_triple}" PARENT_SCOPE)
    set(VCPKG_RUST_TARGET_TRIPLE "${_target_triple}" PARENT_SCOPE)
    set(VCPKG_CARGO_VERSION "${_cargo_version}" PARENT_SCOPE)
    set(VCPKG_CARGO_HOME "${_cargo_home}" PARENT_SCOPE)
    set(VCPKG_CARGO_BIN_DIR "${_cargo_bin_dir}" PARENT_SCOPE)
    set(VCPKG_CARGO_PATH_SEP "${_path_sep}" PARENT_SCOPE)
endfunction()

# vcpkg_cargo_build(...)
#
# Generic cargo build driver for pure Rust ports.
#
# Arguments:
#   SOURCE_PATH <dir>     directory containing the cargo workspace   (required)
#   [MANIFEST <file>]     Cargo.toml to build                         (default: ${SOURCE_PATH}/Cargo.toml)
#   [PROFILE <cfg>]       only build the given profile: debug|release (default: both)
#   [FEATURES <list>]     cargo features to enable
#   [ARGS <list>]         extra arguments passed to `cargo build`
#
# The build always runs with `--target <triple mapped from the vcpkg triplet>`; the
# artifacts are placed in `<SOURCE_PATH>/target/<triple>/<debug|release>/`.
function(vcpkg_cargo_build)
    cmake_parse_arguments(PARSE_ARGV 0 arg "" "SOURCE_PATH;MANIFEST;PROFILE" "FEATURES;ARGS")

    if(NOT arg_SOURCE_PATH)
        message(FATAL_ERROR "vcpkg_cargo_build requires SOURCE_PATH")
    endif()
    if(NOT arg_MANIFEST)
        set(arg_MANIFEST "${arg_SOURCE_PATH}/Cargo.toml")
    endif()
    if(NOT arg_PROFILE)
        set(_profiles release debug)
    elseif(arg_PROFILE MATCHES "^(release|debug)$")
        set(_profiles "${arg_PROFILE}")
    else()
        message(FATAL_ERROR "vcpkg_cargo_build PROFILE must be 'release' or 'debug'")
    endif()

    vcpkg_cargo_setup()
    # Propagate the setup results to the caller: vcpkg_cargo_setup exports them
    # to the scope of this function when reached through vcpkg_cargo_build.
    foreach(_var IN ITEMS
        VCPKG_CARGO_EXECUTABLE VCPKG_RUSTC_EXECUTABLE VCPKG_RUST_HOST_TRIPLE
        VCPKG_RUST_TARGET_TRIPLE VCPKG_CARGO_VERSION VCPKG_CARGO_HOME
        VCPKG_CARGO_BIN_DIR VCPKG_CARGO_PATH_SEP)
        set(${_var} "${${_var}}" PARENT_SCOPE)
    endforeach()

    set(_feature_args "")
    if(arg_FEATURES)
        list(JOIN arg_FEATURES "," _features_joined)
        set(_feature_args "--features=${_features_joined}")
    endif()

    foreach(_profile IN LISTS _profiles)
        set(_command "${VCPKG_CARGO_EXECUTABLE}" build "--manifest-path=${arg_MANIFEST}")
        if(_profile STREQUAL "release")
            list(APPEND _command --release)
        endif()
        list(APPEND _command "--target=${VCPKG_RUST_TARGET_TRIPLE}")
        if(_feature_args)
            list(APPEND _command "${_feature_args}")
        endif()
        if(arg_ARGS)
            list(APPEND _command ${arg_ARGS})
        endif()

        message(STATUS "cargo build (${_profile}, ${VCPKG_RUST_TARGET_TRIPLE}) ${arg_SOURCE_PATH}")
        vcpkg_execute_required_process(
            COMMAND ${_command}
            WORKING_DIRECTORY "${arg_SOURCE_PATH}"
            LOGNAME "cargo-${_profile}-${TARGET_TRIPLET}"
        )
    endforeach()
endfunction()
