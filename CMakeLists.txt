# Defines BitShares library target.
cmake_minimum_required( VERSION 3.2 FATAL_ERROR )
project( BitShares LANGUAGES CXX C)

set( BLOCKCHAIN_NAME "BitShares" )

set( CLI_CLIENT_EXECUTABLE_NAME graphene_client )
set( GUI_CLIENT_EXECUTABLE_NAME BitShares )
set( CUSTOM_URL_SCHEME "gcs" )
set( INSTALLER_APP_ID "68ad7005-8eee-49c9-95ce-9eed97e5b347" )

set( CMAKE_CXX_STANDARD 14 )
set( CMAKE_CXX_STANDARD_REQUIRED ON )

if( "${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU" OR
    "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" )
  set( CMAKE_CXX_EXTENSIONS ON ) # for __int128 support
else()
  set( CMAKE_CXX_EXTENSIONS OFF )
endif()

# http://stackoverflow.com/a/18369825
if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
    if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 4.8)
        message(FATAL_ERROR "GCC version must be at least 4.8!")
    endif()
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 3.3)
        message(FATAL_ERROR "Clang version must be at least 3.3!")
    endif()
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
    if ("${CMAKE_CXX_COMPILER_VERSION}" VERSION_LESS "19.0")
      message(FATAL_ERROR "MSVC version must be at least 19.0 (Visual Studio 2015 Update 1)!")
    endif()

    # allow MSVC VS2015 with Update 1, other 2015 versions are not supported
    if ("${CMAKE_CXX_COMPILER_VERSION}" VERSION_EQUAL "19.0")
        if (NOT CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL "19.0.23506.0")
            message(FATAL_ERROR "Your version ${CMAKE_CXX_COMPILER_VERSION} of MSVC is not supported, use version 19.0.23506.0 (Visual Studio 2015 Update 1)!")
        endif()
    endif()
endif()

list( APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMakeModules" )

# --------
  # FIX (for rare errors re missing lib editline)v Include top-level vendor validation system FIRST
  # This prevents the recurring git clean -xdf + stale Makefile issue
  include(cmake_top_level_vendor_validator)
# --------

include(CheckCCompilerFlag)
include(Utils)

include(LinkerChoice)

set(_use_ccache_values "auto" "true" "false" "disable_launcher")
set(USE_CCACHE "auto" CACHE STRING
    "Control use of ccache:
     - auto: use ccache if installed (warn if not found)
     - true: always require ccache (error if not found)
     - false: do not use ccache
     - disable_launcher: force unset compiler launchers to make more sure ccache is NOT used"
)
set_property(CACHE USE_CCACHE PROPERTY STRINGS ${_use_ccache_values})


# Normalize to lowercase
string(TOLOWER "${USE_CCACHE}" USE_CCACHE)

if(USE_CCACHE STREQUAL "auto")
    find_program(CCACHE_PROGRAM ccache)
    if(CCACHE_PROGRAM)
        message(STATUS "USE_CCACHE=auto: found ccache, enabling it")
        set(CMAKE_C_COMPILER_LAUNCHER   "${CCACHE_PROGRAM}")
        set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    else()
        message(WARNING "USE_CCACHE=auto: ccache not found, but recommended for faster builds")
    endif()

elseif(USE_CCACHE STREQUAL "true")
    find_program(CCACHE_PROGRAM ccache REQUIRED)
    message(STATUS "USE_CCACHE=true: forcing use of ccache")
    set(CMAKE_C_COMPILER_LAUNCHER   "${CCACHE_PROGRAM}")
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")

elseif(USE_CCACHE STREQUAL "false")
    message(WARNING "USE_CCACHE=false: not changing LAUNCHE")

elseif(USE_CCACHE STREQUAL "disable_launcher")
    message(WARNING "USE_CCACHE=disable_launcher: explicitly disabling compiler launchers")
    set(CMAKE_C_COMPILER_LAUNCHER   "")
    set(CMAKE_CXX_COMPILER_LAUNCHER "")

else()
    message(FATAL_ERROR "Invalid value for USE_CCACHE: ${USE_CCACHE}. Allowed: auto, true, false, disable_launcher")
endif()


# function to help with cUrl
macro(FIND_CURL)
   if (NOT WIN32 AND NOT APPLE AND CURL_STATICLIB)
      find_package(OpenSSL REQUIRED)
      set (OLD_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES})
      set (CMAKE_FIND_LIBRARY_SUFFIXES .a)
      find_package(CURL REQUIRED)
      list(APPEND CURL_LIBRARIES ${OPENSSL_LIBRARIES} ${BOOST_THREAD_LIBRARY} ${CMAKE_DL_LIBS})
      set (CMAKE_FIND_LIBRARY_SUFFIXES ${OLD_SUFFIXES})
   else (NOT WIN32 AND NOT APPLE AND CURL_STATICLIB)
      find_package(CURL REQUIRED)
   endif (NOT WIN32 AND NOT APPLE AND CURL_STATICLIB)

   if( APPLE AND NOT "${CURL_VERSION_STRING}" VERSION_LESS "7.77.0" )
      list( APPEND CURL_LIBRARIES "-framework CoreFoundation" )
      list( APPEND CURL_LIBRARIES "-framework SystemConfiguration" )
   endif()

   message(STATUS "CURL libraries: ${CURL_LIBRARIES}")

   if( WIN32 )
     if ( MSVC )
       list( APPEND CURL_LIBRARIES Wldap32 )
     endif( MSVC )

     if( MINGW )
       # MinGW requires a specific order of included libraries ( CURL before ZLib )
       find_package( ZLIB REQUIRED )
       list( APPEND CURL_LIBRARIES ${ZLIB_LIBRARY} pthread )
     endif( MINGW )

     list( APPEND CURL_LIBRARIES ${PLATFORM_SPECIFIC_LIBS} )
   endif( WIN32 )
endmacro()

# Save the old value of CMAKE_REQUIRED_FLAGS
set( TEMP_REQUIRED_FLAGS ${CMAKE_REQUIRED_FLAGS} )

# Check submodules
if(NOT MANUAL_SUBMODULES)
  find_package(Git)
  if(GIT_FOUND)
    function (check_submodule relative_path)
      execute_process(COMMAND git rev-parse "HEAD" WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${relative_path} OUTPUT_VARIABLE localHead)
      execute_process(COMMAND git rev-parse "HEAD:${relative_path}" WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} OUTPUT_VARIABLE checkedHead)
      string(COMPARE EQUAL "${localHead}" "${checkedHead}" upToDate)
      if (upToDate)
        message(STATUS "Submodule '${relative_path}' is up-to-date")
      else()
        message(FATAL_ERROR "Submodule '${relative_path}' is not up-to-date. Please update all submodules with\ngit submodule update --init --recursive --force\nor run cmake with -DMANUAL_SUBMODULES=1\n")
      endif()
    endfunction ()

    message(STATUS "Checking submodules")
    check_submodule(docs)
    check_submodule(libraries/fc)
  endif()
endif()
# Make sure to always re-run the test.
unset( MANUAL_SUBMODULES CACHE )

# Fortify source
if (CMAKE_COMPILER_IS_GNUCXX)
	if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
		message (STATUS "Setting optimizations for clang++")
		set(CMAKE_CXX_FLAGS_RELEASE "-D_FORTIFY_SOURCE=2 -O3 -DNDEBUG=1")
		set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "-D_FORTIFY_SOURCE=2 -O3 -DNDEBUG=1 -g")

		# check and add data execution prevention
		message (STATUS "Enabling data execution prevention")
		add_linker_flag("-fsanitize=safe-stack")

		# check and add Stack-based buffer overrun detection
		set(CMAKE_REQUIRED_FLAGS "-fstack-protector")
		check_c_compiler_flag("" HAVE_STACKPROTECTOR)
		if(HAVE_STACKPROTECTOR)
			message (STATUS "Enabling stack-based buffer overrun detection")
			add_flag_append(CMAKE_C_FLAGS "-fstack-protector")
			add_flag_append(CMAKE_CXX_FLAGS "-fstack-protector")
		endif()
	else ()
		message (STATUS "Setting optimizations for g++")
		set(CMAKE_CXX_FLAGS_RELEASE "-D_FORTIFY_SOURCE=2 -O3 -DNDEBUG=1")
		set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "-D_FORTIFY_SOURCE=2 -O3 -DNDEBUG=1 -g")

		# check and add data execution prevention
		set(CMAKE_REQUIRED_FLAGS "-Wl,-znoexecstack")
		check_c_compiler_flag("" HAVE_NOEXECSTACK)
		if(HAVE_NOEXECSTACK)
			message (STATUS "Enabling data execution prevention")
			add_linker_flag("-znoexecstack")
		endif()

		# check and add Stack-based buffer overrun detection
		set(CMAKE_REQUIRED_FLAGS "-fstack-protector-strong")
		check_c_compiler_flag("" HAVE_STACKPROTECTOR)
		if(HAVE_STACKPROTECTOR)
			message (STATUS "Enabling stack-based buffer overrun detection")
			add_flag_append(CMAKE_C_FLAGS "-fstack-protector-strong")
			add_flag_append(CMAKE_CXX_FLAGS "-fstack-protector-strong")
		endif()

	endif ()
endif ()

# check for Data relocation and Protection (RELRO)
set(CMAKE_REQUIRED_FLAGS "-Wl,-zrelro,-znow")
check_c_compiler_flag("" HAVE_RELROFULL)
if(HAVE_RELROFULL)
	message (STATUS "Enabling full data relocation and protection")
	add_linker_flag("-zrelro")
	add_linker_flag("-znow")
else()
	#if full relro is not available, try partial relro
	set(CMAKE_REQUIRED_FLAGS "-Wl,-zrelro")
	check_c_compiler_flag("" HAVE_RELROPARTIAL)
	if(HAVE_RELROPARTIAL)
		message (STATUS "Enabling partial data relocation and protection")
		add_linker_flag("-zrelro")
	endif()
endif()

set(CMAKE_REQUIRED_FLAGS ${TEMP_REQUIRED_FLAGS} )

# position independent executetable (PIE)
# position independent code (PIC)
if (NOT MSVC)
    add_definitions (-fPIC)
endif(NOT MSVC)

set(CMAKE_EXPORT_COMPILE_COMMANDS "ON")
set( GRAPHENE_EGENESIS_JSON "${CMAKE_CURRENT_SOURCE_DIR}/libraries/egenesis/genesis.json"
     CACHE STRING "Path to embedded genesis file" )

if (USE_PCH)
  include (cotire)
endif(USE_PCH)

option(USE_PROFILER "Build with GPROF support(Linux)." OFF)

# Use Boost config file from fc
set(Boost_DIR "${CMAKE_CURRENT_SOURCE_DIR}/libraries/fc/CMakeModules/Boost")

list( APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/libraries/fc/GitVersionGen" )
include( GetGitRevisionDescription )
get_git_head_revision( GIT_REFSPEC GIT_SHA2 )

SET(BOOST_COMPONENTS)
LIST(APPEND BOOST_COMPONENTS thread
                             iostreams
                             date_time
                             system
                             filesystem
                             program_options
                             chrono
                             unit_test_framework
                             context
                             coroutine
                             regex)
# boost::endian is also required, but FindBoost can't handle header-only libs
SET( Boost_USE_STATIC_LIBS ON CACHE STRING "ON or OFF" )

IF(WIN32)
   if($ENV{BOOST_ROOT})
       SET(BOOST_ROOT $ENV{BOOST_ROOT})
   endif($ENV{BOOST_ROOT})
  set(Boost_USE_MULTITHREADED ON)
  set(BOOST_ALL_DYN_LINK OFF) # force dynamic linking for all libraries
  add_definitions("-DCURL_STATICLIB")
  list(APPEND PLATFORM_SPECIFIC_LIBS ws2_32 crypt32 mswsock userenv )
ELSE( WIN32 )
   IF( APPLE )
      set( CMAKE_THREAD_LIBS_INIT "-lpthread" )
      set( CMAKE_HAVE_THREADS_LIBRARY 1 )
      set( CMAKE_USE_WIN32_THREADS_INIT 0 )
      set( CMAKE_USE_PTHREADS_INIT 1 )
      set( THREADS_PREFER_PTHREAD_FLAG ON )
   ENDIF( APPLE )
ENDIF(WIN32)

FIND_PACKAGE(Boost CONFIG REQUIRED COMPONENTS ${BOOST_COMPONENTS})

# enforce more strict compiler warnings and errors
add_compiler_flag_if_available("-Wall")
add_compiler_flag_if_available("-Wclobbered")
add_compiler_flag_if_available("-Wempty-body")
add_compiler_flag_if_available("-Wformat-security")
add_compiler_flag_if_available("-Wignored-qualifiers")
add_compiler_flag_if_available("-Wimplicit-fallthrough=5")
add_compiler_flag_if_available("-Wmissing-field-initializers")
add_compiler_flag_if_available("-Wpointer-arith")
add_compiler_flag_if_available("-Wshift-negative-value")
add_compiler_flag_if_available("-Wtype-limits")
add_compiler_flag_if_available("-Wunused-but-set-parameter")

# libraries/protocol/custom_authorities/safe_compare.hpp see EXP_TEMPLATE_DISAMBIG
# (despite this setting, some new compilers will hard abort anyway, so we fix the C++ code too, in that file)
# see i.e. https://github.com/llvm/llvm-project/issues/94194
add_compiler_flag_if_available("-Wno-error=missing-template-arg-list-after-template-kw")

if( WIN32 )

    message( STATUS "Configuring BitShares on WIN32")

    if ( MINGW )
        message( STATUS "Windows build using MinGW" )
        set( FULL_STATIC_BUILD TRUE )
    else( MINGW )
        set( ZLIB_LIBRARIES "" )
    endif( MINGW )

    SET( DEFAULT_EXECUTABLE_INSTALL_DIR bin/ )

    if( MSVC )
        add_definitions(-DWIN32_LEAN_AND_MEAN)
        #looks like this flag can have different default on some machines.
        SET(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /SAFESEH:NO")
        SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SAFESEH:NO")

        # Probably cmake has a bug and vcxproj generated for executable in Debug conf. has disabled debug info
        set(CMAKE_EXE_LINKER_FLAGS_DEBUG "${CMAKE_EXE_LINKER_FLAGS_DEBUG} /DEBUG")
    endif ( MSVC )

else( WIN32 ) # Apple AND Linux

    if( APPLE )
        # Apple Specific Options Here
        message( STATUS "Configuring BitShares on macOS" )
        set( CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -stdlib=libc++ -Wall -fvisibility-inlines-hidden -fvisibility=hidden" )
    else( APPLE )
        if ( "${CMAKE_SYSTEM_NAME}" STREQUAL "OpenBSD" )
            # OpenBSD Specific Options
            message( STATUS "Configuring BitShares on OpenBSD" )
        else()
            # Linux Specific Options Here
            message( STATUS "Configuring BitShares on Linux" )
            set( rt_library rt )
        endif()
        # Common Linux & OpenBSD Options
        set( CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -Wall" )
        if(USE_PROFILER)
            set( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pg" )
        endif( USE_PROFILER )
        set( pthread_library pthread)
        if ( NOT DEFINED crypto_library )
          # I'm not sure why this is here, I guess someone has openssl and can't detect it with find_package()?
          # if you have a normal install, you can define crypto_library to the empty string to avoid a build error
          set( crypto_library crypto)
        endif ()
    endif( APPLE )

    if( "${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU" )
        set( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-builtin-memcmp" )
    elseif( "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" )
        if( CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 4.0.0 OR CMAKE_CXX_COMPILER_VERSION VERSION_GREATER 4.0.0 )
            set( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-invalid-partial-specialization" )
        endif()
    endif()

    if( "${CMAKE_GENERATOR}" STREQUAL "Ninja" )
        if( "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" )
            set( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fcolor-diagnostics" )
        endif()
    endif()

    # based on http://www.delorie.com/gnu/docs/gdb/gdb_70.html
    # uncomment this line to tell GDB about macros (slows compile times)
    # set( CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -gdwarf-2 -g3" )

endif( WIN32 )

if ( NOT MSVC AND FULL_STATIC_BUILD )
    set( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static -static-libstdc++ -static-libgcc" )
endif ( NOT MSVC AND FULL_STATIC_BUILD )

set(ENABLE_COVERAGE_TESTING FALSE CACHE BOOL "Build BitShares for code coverage analysis")

if(ENABLE_COVERAGE_TESTING)
    SET(CMAKE_CXX_FLAGS "--coverage ${CMAKE_CXX_FLAGS}")
endif()

add_flag_append(CMAKE_CXX_FLAGS "-DBOOST_BIND_GLOBAL_PLACEHOLDERS") # to quiet the warnings (seen on Ubuntu 24.04 for example) about default _1 globals of boost (default to old behaviour of boost, this is what the code base expects)


# -----------------------------------------------

message(NOTICE "-----------------------------------------------")
# Convert build type to uppercase - to check variable below
string(TOUPPER "${CMAKE_BUILD_TYPE}" BUILD_TYPE_UPPER)

# final flags considering the build type
set(FINAL_C_FLAGS "${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${BUILD_TYPE_UPPER}}")
set(FINAL_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_${BUILD_TYPE_UPPER}}")

# Print the used flags
message(NOTICE "### CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}")

message(NOTICE "... CMAKE_C_FLAGS: ${CMAKE_C_FLAGS}")
message(NOTICE "... CMAKE_C_FLAGS_${BUILD_TYPE_UPPER}: ${CMAKE_C_FLAGS_${BUILD_TYPE_UPPER}}")
message(NOTICE "### FINAL_C_FLAGS: ${FINAL_C_FLAGS}")

message(NOTICE "... CMAKE_CXX_FLAGS: ${CMAKE_CXX_FLAGS}")
message(NOTICE "... CMAKE_CXX_FLAGS_${BUILD_TYPE_UPPER}: ${CMAKE_CXX_FLAGS_${BUILD_TYPE_UPPER}}")
message(NOTICE "### FINAL_CXX_FLAGS: ${FINAL_CXX_FLAGS}")
message(NOTICE "-----------------------------------------------")

# -----------------------------------------------

add_subdirectory( libraries )

# --------
  # FIX (for rare errors re missing lib editline)v Include top-level vendor validation system FIRST
  # BUILD ORDER ENFORCEMENT: Libraries must complete before programs/tests
  # This ensures vendor dependencies are fully built before any dependent targets

  # After libraries are configured, create the project-wide vendor barrier
  validate_fc_vendor_dependencies()
  create_project_wide_vendor_barrier()
# --------

# Now programs and tests can safely depend on vendor libraries
add_subdirectory( programs )
add_subdirectory( tests )


if (ENABLE_INSTALLER)

set(VERSION_MAJOR 0)
set(VERSION_MINOR 1)
set(VERSION_PATCH 0)


include(InstallRequiredSystemLibraries)

set(CPACK_OUTPUT_FILE_PREFIX ${CMAKE_BINARY_DIR}/packages)
set(CMAKE_INSTALL_PREFIX ${CMAKE_BINARY_DIR}/install)

SET(CPACK_PACKAGE_DIRECTORY "${CMAKE_INSTALL_PREFIX}")
set(CPACK_PACKAGE_NAME "graphene")
set(CPACK_PACKAGE_VENDOR "Cryptonomex, Inc.")
set(CPACK_PACKAGE_VERSION_MAJOR "${VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH "${VERSION_PATCH}")
set(CPACK_PACKAGE_VERSION "${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH}")
set(CPACK_PACKAGE_DESCRIPTION "A client for the BitShares network")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "A client for the BitShares network")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.md")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "BitShares ${CPACK_PACKAGE_VERSION}")

if(WIN32)
 SET(CPACK_GENERATOR "ZIP;NSIS")
 set(CPACK_PACKAGE_NAME "BitShares") # override above
 set(CPACK_NSIS_EXECUTABLES_DIRECTORY .)
 set(CPACK_NSIS_PACKAGE_NAME "BitShares v${CPACK_PACKAGE_VERSION}")
 set(CPACK_NSIS_DISPLAY_NAME "${CPACK_NSIS_PACKAGE_NAME}")
 set(CPACK_NSIS_DEFINES "  !define MUI_STARTMENUPAGE_DEFAULTFOLDER \\\"BitShares\\\"")
 # it seems like windows zip files usually don't have a single directory inside them, unix tgz frequently do
 SET(CPACK_INCLUDE_TOPLEVEL_DIRECTORY 0)

endif(WIN32)

if(APPLE)
  set(CPACK_GENERATOR "DragNDrop")
endif()

if(LINUX)
  # Linux gets a .tgz
  SET(CPACK_GENERATOR "TGZ")
  SET(CPACK_INCLUDE_TOPLEVEL_DIRECTORY 1)
endif(LINUX)

 include(CPack)
endif(ENABLE_INSTALLER)

MESSAGE( STATUS "" )
MESSAGE( STATUS "PROFILER: ${USE_PROFILER}" )
MESSAGE( STATUS "" )

message(STATUS "========== Build Configuration Summary (top of $PROJECT_NAME) ==========")
message(STATUS "Project: ${PROJECT_NAME}")
message(STATUS "Generator: ${CMAKE_GENERATOR}")
if(CMAKE_GENERATOR_PLATFORM)
    message(STATUS "Generator Platform: ${CMAKE_GENERATOR_PLATFORM}")
endif()
if(CMAKE_GENERATOR_TOOLSET)
    message(STATUS "Generator Toolset: ${CMAKE_GENERATOR_TOOLSET}")
endif()

# Compilers
message(STATUS "C Compiler:   ${CMAKE_C_COMPILER}")
message(STATUS "C++ Compiler: ${CMAKE_CXX_COMPILER}")

if(DEFINED CMAKE_C_COMPILER_LAUNCHER AND NOT "${CMAKE_C_COMPILER_LAUNCHER}" STREQUAL "")
    message(STATUS "C Compiler Launcher:   ${CMAKE_C_COMPILER_LAUNCHER}")
else()
    message(STATUS "C Compiler Launcher:   (none)")
endif()
if(DEFINED CMAKE_CXX_COMPILER_LAUNCHER AND NOT "${CMAKE_CXX_COMPILER_LAUNCHER}" STREQUAL "")
    message(STATUS "C++ Compiler Launcher: ${CMAKE_CXX_COMPILER_LAUNCHER}")
else()
    message(STATUS "C++ Compiler Launcher: (none)")
endif()

# Compiler flags
message(STATUS "C Flags:   ${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE}}")
message(STATUS "C++ Flags: ${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}}")

message(STATUS "=================================================")


if(UNIX)
  set(BUILD_DIR "${CMAKE_BINARY_DIR}")

  set(LINK_PATH "$ENV{PWD}/use")

  add_custom_target(create_use_symlink ALL
    COMMAND ${CMAKE_COMMAND} -E remove -f "${LINK_PATH}"
    COMMAND ${CMAKE_COMMAND} -E create_symlink "${BUILD_DIR}" "${LINK_PATH}"
    COMMENT "Creating symlink ${LINK_PATH} -> ${BUILD_DIR}"
    VERBATIM
  )
endif()

