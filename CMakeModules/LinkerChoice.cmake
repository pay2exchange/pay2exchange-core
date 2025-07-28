# cmake/LinkerSetup.cmake
# vibecoded

# 1. Option to pick your linker
set(USE_FAST_LINKER "Auto"
    CACHE STRING
    "Which linker to use: Auto, Mold, LLD, Gold, or System")
set_property(CACHE USE_FAST_LINKER
             PROPERTY STRINGS Auto Mold LLD Gold System)

# 2. Probe for available linkers
find_program(MOLD_EXECUTABLE NAMES mold)
find_program(LLD_EXECUTABLE  NAMES ld.lld lld)
find_program(GOLD_EXECUTABLE NAMES ld.gold gold)

# 3. Decide which linker to use
string(TOUPPER "${USE_FAST_LINKER}" _CHOICE)
set(SELECTED_LINKER "")

if(_CHOICE STREQUAL "SYSTEM")
  # leave SELECTED_LINKER empty → system default

elseif(_CHOICE STREQUAL "MOLD")
  if(MOLD_EXECUTABLE)
    set(SELECTED_LINKER mold)
  else()
    message(WARNING "mold not found; using system linker")
  endif()

elseif(_CHOICE STREQUAL "LLD")
  if(LLD_EXECUTABLE)
    set(SELECTED_LINKER lld)
  else()
    message(WARNING "LLVM LLD not found; using system linker")
  endif()

elseif(_CHOICE STREQUAL "GOLD")
  if(GOLD_EXECUTABLE)
    set(SELECTED_LINKER gold)
  else()
    message(WARNING "gold not found; using system linker")
  endif()

elseif(_CHOICE STREQUAL "AUTO")
  if(MOLD_EXECUTABLE)
    set(SELECTED_LINKER mold)
  elseif(LLD_EXECUTABLE)
    set(SELECTED_LINKER lld)
  elseif(GOLD_EXECUTABLE)
    set(SELECTED_LINKER gold)
  endif()
  message(NOTICE "Auto selecting linker: ${SELECTED_LINKER}")

else()
  message(WARNING
    "Unknown USE_FAST_LINKER='${USE_FAST_LINKER}', defaulting to system")
endif()

# 4. Apply the selection
if(SELECTED_LINKER)
  message(STATUS "Using '${SELECTED_LINKER}' linker")

  if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.29)
    string(TOUPPER "${SELECTED_LINKER}" _TYPE)
    set(CMAKE_LINKER_TYPE ${_TYPE} CACHE STRING "" FORCE)
  else()
    foreach(_var IN ITEMS
        CMAKE_EXE_LINKER_FLAGS
        CMAKE_SHARED_LINKER_FLAGS)
      set(${_var}
          "-fuse-ld=${SELECTED_LINKER} ${${_var}}"
          CACHE STRING "Flags passed to linker" FORCE)
    endforeach()
  endif()
else()
  message(STATUS "Using system default linker")
endif()
