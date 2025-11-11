add_executable( size_checker main.cpp )
if( UNIX AND NOT APPLE )
  set(rt_library rt )
endif()

target_link_libraries( size_checker
                       PRIVATE graphene_chain graphene_egenesis_none fc ${CMAKE_DL_LIBS} ${PLATFORM_SPECIFIC_LIBS} )

# Ensure size_checker depends on external projects to prevent race conditions in parallel builds
if(NOT WIN32)
  add_dependencies(size_checker project_editline project_secp256k1)
endif(NOT WIN32)

# Add P2E tools installation
add_p2e_tools_install(size_checker)

install( TARGETS
   size_checker

   RUNTIME DESTINATION bin
   LIBRARY DESTINATION lib
   ARCHIVE DESTINATION lib
)
