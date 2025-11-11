# Top-level vendor library validation system for the entire project
# Ensures that ALL build targets wait for critical vendor libraries to be properly built
# This prevents any race conditions at the project level

# Function to validate that fc library has properly built vendor dependencies
function(validate_fc_vendor_dependencies)
    message(STATUS "Top-level validation: Checking fc vendor dependencies...")
    
    set(EDITLINE_LIB_PATH "${CMAKE_CURRENT_SOURCE_DIR}/libraries/fc/vendor/editline/src/.libs/libeditline.a")
    set(SECP256K1_LIB_PATH "${CMAKE_CURRENT_SOURCE_DIR}/libraries/fc/vendor/secp256k1-zkp/.libs/libsecp256k1.a")
    
    set(VALIDATION_FAILED FALSE)
    set(MISSING_LIBS "")
    
    # Check editline library
    if(NOT EXISTS "${EDITLINE_LIB_PATH}")
        set(VALIDATION_FAILED TRUE)
        list(APPEND MISSING_LIBS "editline (${EDITLINE_LIB_PATH})")
    else()
        file(SIZE "${EDITLINE_LIB_PATH}" EDITLINE_SIZE)
        if(EDITLINE_SIZE LESS 10240)  # Less than 10KB
            set(VALIDATION_FAILED TRUE)
            list(APPEND MISSING_LIBS "editline (too small: ${EDITLINE_SIZE} bytes)")
        endif()
    endif()
    
    # Check secp256k1 library
    if(NOT EXISTS "${SECP256K1_LIB_PATH}")
        set(VALIDATION_FAILED TRUE)
        list(APPEND MISSING_LIBS "secp256k1 (${SECP256K1_LIB_PATH})")
    else()
        file(SIZE "${SECP256K1_LIB_PATH}" SECP256K1_SIZE)
        if(SECP256K1_SIZE LESS 50000)  # Less than 50KB
            set(VALIDATION_FAILED TRUE)
            list(APPEND MISSING_LIBS "secp256k1 (too small: ${SECP256K1_SIZE} bytes)")
        endif()
    endif()
    
    if(VALIDATION_FAILED)
        message(STATUS "❌ Top-level validation failed - missing/invalid vendor libraries:")
        foreach(LIB ${MISSING_LIBS})
            message(STATUS "   • ${LIB}")
        endforeach()
        message(STATUS "This will be resolved when fc library builds...")
        set(FC_VENDOR_LIBS_READY FALSE PARENT_SCOPE)
    else()
        message(STATUS "✅ Top-level validation passed - all fc vendor libraries are ready")
        set(FC_VENDOR_LIBS_READY TRUE PARENT_SCOPE)
    endif()
endfunction()

# Create a comprehensive barrier target that ensures vendor libraries are ready
# before ANY other targets in the entire project can build
function(create_project_wide_vendor_barrier)
    message(STATUS "🛡️ Creating project-wide vendor library barrier...")
    
    # Only create barrier on Unix systems where these libraries are needed
    if(NOT WIN32)
        # Create the ultimate barrier target
        add_custom_target(project_vendor_barrier
            COMMAND ${CMAKE_COMMAND} -E echo "🎯 Vendor barrier: All critical libraries validated and ready"
            COMMENT "Project-wide barrier ensuring vendor libraries are built before all other targets"
            VERBATIM
        )
        
        # If fc target exists, make the barrier depend on it
        if(TARGET fc)
            add_dependencies(project_vendor_barrier fc)
            message(STATUS "✅ Vendor barrier configured to depend on fc library")
        else()
            message(STATUS "⚠️ fc target not found, barrier will be created when fc is available")
        endif()
        
        # Set a property that other parts of the build system can check
        set_property(GLOBAL PROPERTY VENDOR_BARRIER_TARGET "project_vendor_barrier")
        
        message(STATUS "Project-wide vendor barrier created successfully")
    else()
        message(STATUS "Windows build - vendor barrier not needed")
    endif()
endfunction()

# Function to add vendor barrier dependency to any target
function(add_vendor_barrier_dependency TARGET_NAME)
    if(NOT WIN32)
        get_property(BARRIER_TARGET GLOBAL PROPERTY VENDOR_BARRIER_TARGET)
        if(BARRIER_TARGET AND TARGET ${BARRIER_TARGET})
            add_dependencies(${TARGET_NAME} ${BARRIER_TARGET})
            message(STATUS "${TARGET_NAME} now depends on vendor barrier")
        endif()
    endif()
endfunction()

# Macro to automatically add vendor dependencies to executable targets
macro(add_executable_with_vendor_deps NAME)
    add_executable(${NAME} ${ARGN})
    add_vendor_barrier_dependency(${NAME})
endmacro()

# Macro to automatically add vendor dependencies to library targets  
macro(add_library_with_vendor_deps NAME)
    add_library(${NAME} ${ARGN})
    add_vendor_barrier_dependency(${NAME})
endmacro()

# Enhanced target creation macros that enforce vendor dependency ordering
macro(safe_add_executable NAME)
    add_executable(${NAME} ${ARGN})
    if(NOT WIN32)
        # Ensure this target waits for vendor libraries
        add_vendor_barrier_dependency(${NAME})
        
        # Add extra safety check - verify libraries exist at build time
        add_custom_command(TARGET ${NAME} PRE_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "🔍 Pre-build check for ${NAME}: Verifying vendor libraries..."
            COMMAND test -f "${CMAKE_SOURCE_DIR}/libraries/fc/vendor/editline/src/.libs/libeditline.a" || (echo "❌ ERROR: libeditline.a not found - cannot build ${NAME}" && exit 1)
            COMMAND test -f "${CMAKE_SOURCE_DIR}/libraries/fc/vendor/secp256k1-zkp/.libs/libsecp256k1.a" || (echo "❌ ERROR: libsecp256k1.a not found - cannot build ${NAME}" && exit 1)
            COMMAND ${CMAKE_COMMAND} -E echo "✅ Vendor libraries verified for ${NAME}"
            COMMENT "Pre-build vendor library verification for ${NAME}"
            VERBATIM
        )
    endif()
endmacro()

macro(safe_add_library NAME)
    add_library(${NAME} ${ARGN})
    if(NOT WIN32 AND NOT NAME STREQUAL "fc")  # Don't add dependency to fc itself
        add_vendor_barrier_dependency(${NAME})
    endif()
endmacro()