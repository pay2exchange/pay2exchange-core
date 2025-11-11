
add_executable( genesis_update genesis_update.cpp )
if( UNIX AND NOT APPLE )
  set(rt_library rt )
endif()

target_link_libraries( genesis_update
                       PRIVATE graphene_app graphene_chain graphene_egenesis_none fc ${CMAKE_DL_LIBS} ${PLATFORM_SPECIFIC_LIBS} )

# Ensure genesis_update depends on external projects to prevent race conditions in parallel builds
if(NOT WIN32)
  add_dependencies(genesis_update project_editline project_secp256k1)
endif(NOT WIN32)

# Add P2E tools installation
add_p2e_tools_install(genesis_update)

install( TARGETS
   genesis_update

   RUNTIME DESTINATION bin
   LIBRARY DESTINATION lib
   ARCHIVE DESTINATION lib
)

add_executable( get_dev_key get_dev_key.cpp )

target_link_libraries( get_dev_key
                       PRIVATE graphene_utilities graphene_protocol fc ${CMAKE_DL_LIBS} ${PLATFORM_SPECIFIC_LIBS} )

# Ensure get_dev_key depends on external projects to prevent race conditions in parallel builds
if(NOT WIN32)
  add_dependencies(get_dev_key project_editline project_secp256k1)
endif(NOT WIN32)

# Add P2E tools installation
add_p2e_tools_install(get_dev_key)

install( TARGETS
   get_dev_key

   RUNTIME DESTINATION bin
   LIBRARY DESTINATION lib
   ARCHIVE DESTINATION lib
)

add_executable( convert_address convert_address.cpp )

target_link_libraries( convert_address
                       PRIVATE graphene_chain fc ${CMAKE_DL_LIBS} ${PLATFORM_SPECIFIC_LIBS} )

# Ensure convert_address depends on external projects to prevent race conditions in parallel builds
if(NOT WIN32)
  add_dependencies(convert_address project_editline project_secp256k1)
endif(NOT WIN32)

# Add P2E tools installation
add_p2e_tools_install(convert_address)
