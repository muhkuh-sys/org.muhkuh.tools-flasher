PROJECT("luaexpat")

INCLUDE(ExternalProject)

SET(VERSION_EXTERNAL "1.5.0")

SET(PRJ_CMAKE_ARGS "")
LIST(APPEND PRJ_CMAKE_ARGS "-DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}")
LIST(APPEND PRJ_CMAKE_ARGS "-DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}")
LIST(APPEND PRJ_CMAKE_ARGS "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}")
LIST(APPEND PRJ_CMAKE_ARGS "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
IF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
	LIST(APPEND PRJ_CMAKE_ARGS "-DCMAKE_RC_COMPILER=${CMAKE_RC_COMPILER}")
ENDIF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")

LIST(APPEND PRJ_CMAKE_ARGS "-DLUA_INCLUDE_DIR=${LUA_INCLUDE_DIR}")
LIST(APPEND PRJ_CMAKE_ARGS "-DLUA_LIBRARIES=${LUA54_LIBRARIES}")

LIST(APPEND PRJ_CMAKE_ARGS "-DLIBEXPAT_INCLUDE_DIRECTORIES=${CMAKE_BINARY_DIR}/install/dev/include")
LIST(APPEND PRJ_CMAKE_ARGS "-DLIBEXPAT_LIBRARY=${CMAKE_BINARY_DIR}/install/dev/lib/libexpat.a")

IF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
	LIST(APPEND PRJ_CMAKE_ARGS "-DTEST_SCRIPT_FOLDER=${CMAKE_HOME_DIRECTORY}/cmake/tests")
ENDIF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")

LIST(APPEND PRJ_CMAKE_ARGS "-DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/install")
LIST(APPEND PRJ_CMAKE_ARGS "-DPYTHON_INTERPRETER=${PYTHON_INTERPRETER}")

ExternalProject_Add(TARGET_luaexpat
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/luaexpat-${VERSION_EXTERNAL}
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/luaexpat-${VERSION_EXTERNAL}.tar.gz
                    URL_HASH SHA1=ab282414ecb34487c6688a721a570f92541319da
                    PATCH_COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/copy_over ${CMAKE_CURRENT_BINARY_DIR}/luaexpat-${VERSION_EXTERNAL}/src/TARGET_luaexpat
                    CMAKE_ARGS ${PRJ_CMAKE_ARGS}
                    TEST_BEFORE_INSTALL 1
                    TEST_COMMAND pwd && ${CMAKE_MAKE_PROGRAM} test
                    INSTALL_COMMAND ${CMAKE_MAKE_PROGRAM} install
)