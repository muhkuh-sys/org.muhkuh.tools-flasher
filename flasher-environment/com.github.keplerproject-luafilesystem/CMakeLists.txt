PROJECT("luafilesystem")

SET(VERSION_EXTERNAL "1.8.0")


#----------------------------------------------------------------------------
#
# Build the project.
#

SET(SUB_CMAKE_ARGS "")
LIST(APPEND SUB_CMAKE_ARGS "-DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}")
LIST(APPEND SUB_CMAKE_ARGS "-DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}")
LIST(APPEND SUB_CMAKE_ARGS "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}")
LIST(APPEND SUB_CMAKE_ARGS "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
IF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
	LIST(APPEND SUB_CMAKE_ARGS "-DCMAKE_RC_COMPILER=${CMAKE_RC_COMPILER}")
ENDIF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
LIST(APPEND SUB_CMAKE_ARGS "-DLUA_LIBRARIES=${LUA_LIBRARIES}")
LIST(APPEND SUB_CMAKE_ARGS "-DLUA_INCLUDE_DIR=${LUA_INCLUDE_DIR}")
LIST(APPEND SUB_CMAKE_ARGS "-DPYTHON_INTERPRETER=${PYTHON_INTERPRETER}")
LIST(APPEND SUB_CMAKE_ARGS "-DTEST_SCRIPT_FOLDER=${CMAKE_HOME_DIRECTORY}/cmake/tests")


ExternalProject_Add(TARGET_luafilesystem
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/luafilesystem
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/luafilesystem-1_8_0.tar.gz
                    URL_HASH SHA1=d81c8fd0a0a4c206980a9b01fa27cbd1f458031c
                    PATCH_COMMAND "${PYTHON_INTERPRETER}" ${CMAKE_HOME_DIRECTORY}/cmake/tools/apply_patches.py --working-folder ${CMAKE_CURRENT_BINARY_DIR}/luafilesystem/src/TARGET_luafilesystem --copy-folder ${CMAKE_CURRENT_SOURCE_DIR}/copy_over
                    CMAKE_ARGS ${SUB_CMAKE_ARGS}
                    TEST_COMMAND make test
                    INSTALL_COMMAND true
)

SET(BLD_FOLDER "${CMAKE_CURRENT_BINARY_DIR}/luafilesystem/src/TARGET_luafilesystem-build")

# Install the lua module.
INSTALL(FILES ${BLD_FOLDER}/lfs${CMAKE_SHARED_LIBRARY_SUFFIX}
        DESTINATION ${FLASHER_PACKAGE_DIR}/lua_plugins)
