cmake_minimum_required(VERSION 3.20)
project(cppcommon VERSION 1.0.6.0 LANGUAGES CXX)

# Match upstream build settings (CppCMakeScripts): C++23 with compiler extensions
set(CMAKE_CXX_EXTENSIONS ON)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

find_package(fmt CONFIG REQUIRED)
find_package(Threads REQUIRED)

file(GLOB_RECURSE CPPCOMMON_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/source/*.cpp")

add_library(cppcommon ${CPPCOMMON_SOURCES})
add_library(cppcommon::cppcommon ALIAS cppcommon)

target_compile_features(cppcommon PUBLIC cxx_std_23)

if(MSVC)
    target_compile_options(cppcommon PRIVATE /bigobj /utf-8 /Zc:__cplusplus)
elseif(MINGW)
    # MinGW-w64 object files may exceed the default COFF section count limit
    target_compile_options(cppcommon PRIVATE -Wa,-mbig-obj)
endif()

if(WIN32)
    # Windows platform flags from upstream SetPlatformFeatures.cmake
    target_compile_definitions(cppcommon PUBLIC
        WIN32_LEAN_AND_MEAN
        _CRT_SECURE_NO_DEPRECATE
        _SILENCE_ALL_CXX17_DEPRECATION_WARNINGS
        _WIN32_WINNT=0x0A00)
    # Stack trace, RPC and user environment handling
    target_link_libraries(cppcommon PRIVATE Dbghelp Rpcrt4 Userenv)
elseif(APPLE)
    # UUID generation is provided by libSystem; silence duplicate library warnings
    target_link_options(cppcommon PRIVATE -Wl,-no_warn_duplicate_libraries)
else()
    # UUID generation requires libuuid, the shared library loader requires libdl
    find_library(LIBUUID_LIBRARY NAMES uuid libuuid REQUIRED)
    target_link_libraries(cppcommon PRIVATE ${LIBUUID_LIBRARY} ${CMAKE_DL_LIBS})
endif()

target_include_directories(cppcommon
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

target_link_libraries(cppcommon
    PUBLIC
        fmt::fmt
        Threads::Threads)

install(TARGETS cppcommon
    EXPORT cppcommon-targets
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")

install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/"
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cppcommon-config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/cppcommon-config.cmake"
    INSTALL_DESTINATION "${CMAKE_INSTALL_DATADIR}/cppcommon")

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/cppcommon-config-version.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/cppcommon-config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/cppcommon-config-version.cmake"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/cppcommon")

install(EXPORT cppcommon-targets
    NAMESPACE cppcommon::
    DESTINATION "${CMAKE_INSTALL_DATADIR}/cppcommon")
