add_executable( network_mapper network_mapper.cpp )
target_link_libraries( network_mapper fc graphene_chain graphene_net )

# Ensure network_mapper depends on external projects to prevent race conditions in parallel builds
if(NOT WIN32)
  add_dependencies(network_mapper project_editline project_secp256k1)
endif(NOT WIN32)

