# unofficial-ck-config.cmake
# Provides imported target: unofficial::ck::ck

include(CMakeFindDependencyMacro)

if(NOT TARGET unofficial::ck::ck)
    add_library(unofficial::ck::ck UNKNOWN IMPORTED)

    find_path(CK_INCLUDE_DIR NAMES ck_spinlock.h PATH_SUFFIXES include)
    find_library(CK_LIBRARY_RELEASE NAMES ck PATHS "${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/lib" NO_DEFAULT_PATH)
    find_library(CK_LIBRARY_DEBUG   NAMES ck PATHS "${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug/lib" NO_DEFAULT_PATH)

    set_target_properties(unofficial::ck::ck PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${CK_INCLUDE_DIR}"
    )

    if(CK_LIBRARY_RELEASE)
        set_property(TARGET unofficial::ck::ck APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
        set_target_properties(unofficial::ck::ck PROPERTIES
            IMPORTED_LOCATION_RELEASE "${CK_LIBRARY_RELEASE}"
        )
    endif()

    if(CK_LIBRARY_DEBUG)
        set_property(TARGET unofficial::ck::ck APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
        set_target_properties(unofficial::ck::ck PROPERTIES
            IMPORTED_LOCATION_DEBUG "${CK_LIBRARY_DEBUG}"
        )
    endif()

    # 仅有一种配置时设为默认
    if(CK_LIBRARY_RELEASE AND NOT CK_LIBRARY_DEBUG)
        set_target_properties(unofficial::ck::ck PROPERTIES
            IMPORTED_LOCATION "${CK_LIBRARY_RELEASE}"
        )
    elseif(CK_LIBRARY_DEBUG AND NOT CK_LIBRARY_RELEASE)
        set_target_properties(unofficial::ck::ck PROPERTIES
            IMPORTED_LOCATION "${CK_LIBRARY_DEBUG}"
        )
    endif()

    if(UNIX)
        find_dependency(Threads)
        target_link_libraries(unofficial::ck::ck INTERFACE Threads::Threads)
    endif()
endif()
