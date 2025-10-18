add_executable( js_operation_serializer main.cpp )
if( UNIX AND NOT APPLE )
  set(rt_library rt )
endif()

target_link_libraries( js_operation_serializer
                       PRIVATE graphene_app graphene_net graphene_chain graphene_egenesis_none graphene_utilities graphene_wallet fc ${CMAKE_DL_LIBS} ${PLATFORM_SPECIFIC_LIBS} )

# Ensure js_operation_serializer depends on external projects to prevent race conditions in parallel builds
if(NOT WIN32)
  add_dependencies(js_operation_serializer project_editline project_secp256k1)
endif(NOT WIN32)

install( TARGETS
   js_operation_serializer

   RUNTIME DESTINATION bin
   LIBRARY DESTINATION lib
   ARCHIVE DESTINATION lib
)
