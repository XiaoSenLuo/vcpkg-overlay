cmake_minimum_required(VERSION 3.20)
project(cppserver VERSION 1.0.6.0 LANGUAGES CXX)

# Match upstream build settings (CppCMakeScripts): C++23 with compiler extensions
set(CMAKE_CXX_EXTENSIONS ON)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

find_package(OpenSSL REQUIRED)
find_package(asio CONFIG REQUIRED)
find_package(cppcommon CONFIG REQUIRED)
find_package(Threads REQUIRED)

file(GLOB_RECURSE CPPSERVER_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/source/*.cpp")

add_library(cppserver ${CPPSERVER_SOURCES})
add_library(cppserver::cppserver ALIAS cppserver)

target_compile_features(cppserver PUBLIC cxx_std_23)

if(MSVC)
    target_compile_options(cppserver PRIVATE /bigobj /utf-8 /Zc:__cplusplus)
elseif(MINGW)
    # MinGW-w64 object files may exceed the default COFF section count limit
    target_compile_options(cppserver PRIVATE -Wa,-mbig-obj)
endif()

if(WIN32)
    # System libraries from upstream FindWinSock.cmake/FindCrypt.cmake. Note
    # that mswsock is mandatory with GCC/MinGW: asio declares it through
    # '#pragma comment(lib, "mswsock.lib")' which MSVC honors but GCC ignores,
    # leaving AcceptEx/GetAcceptExSockaddrs unresolved at link time.
    target_link_libraries(cppserver PUBLIC ws2_32 mswsock bcrypt crypt32)
elseif(APPLE)
    # Silence duplicate library warnings (upstream SetCompilerFeatures.cmake)
    target_link_options(cppserver PRIVATE -Wl,-no_warn_duplicate_libraries)
endif()

target_include_directories(cppserver
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

target_link_libraries(cppserver
    PUBLIC
        OpenSSL::SSL
        OpenSSL::Crypto
        asio::asio
        cppcommon::cppcommon
        Threads::Threads)

install(TARGETS cppserver
    EXPORT cppserver-targets
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")

install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/"
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cppserver-config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/cppserver-config.cmake"
    INSTALL_DESTINATION "${CMAKE_INSTALL_DATADIR}/cppserver")

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/cppserver-config-version.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/cppserver-config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/cppserver-config-version.cmake"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/cppserver")

install(EXPORT cppserver-targets
    NAMESPACE cppserver::
    DESTINATION "${CMAKE_INSTALL_DATADIR}/cppserver")
