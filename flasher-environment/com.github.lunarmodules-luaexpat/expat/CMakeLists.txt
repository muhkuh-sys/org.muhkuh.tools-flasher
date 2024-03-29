PROJECT("expat")

SET(VERSION_EXTERNAL "2.5.0")


#----------------------------------------------------------------------------
#
# Build the project for the target architecture.
#
# This static library will be linked with a shared object later. Add "-fPIC" on GCC systems or X64 builds break.
IF("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU"  AND  "${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
	SET(LOCAL_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
ELSE("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU"  AND  "${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
	SET(LOCAL_C_FLAGS "${CMAKE_C_FLAGS}")
ENDIF("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU"  AND  "${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")


SET(EXPAT_CMAKE_ARGS "")
LIST(APPEND EXPAT_CMAKE_ARGS "-DEXPAT_BUILD_TOOLS=OFF")
LIST(APPEND EXPAT_CMAKE_ARGS "-DEXPAT_BUILD_EXAMPLES=OFF")
LIST(APPEND EXPAT_CMAKE_ARGS "-DEXPAT_BUILD_TESTS=OFF")
LIST(APPEND EXPAT_CMAKE_ARGS "-DEXPAT_SHARED_LIBS=OFF")
LIST(APPEND EXPAT_CMAKE_ARGS "-DEXPAT_BUILD_DOCS=OFF")
LIST(APPEND EXPAT_CMAKE_ARGS "-DEXPAT_BUILD_FUZZERS=OFF")
LIST(APPEND EXPAT_CMAKE_ARGS "-DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/install/dev")
LIST(APPEND EXPAT_CMAKE_ARGS "-DCMAKE_C_FLAGS=${LOCAL_C_FLAGS}")
LIST(APPEND EXPAT_CMAKE_ARGS "-DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}")
LIST(APPEND EXPAT_CMAKE_ARGS "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}")
LIST(APPEND EXPAT_CMAKE_ARGS "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
IF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
	LIST(APPEND EXPAT_CMAKE_ARGS "-DCMAKE_RC_COMPILER=${CMAKE_RC_COMPILER}")
ENDIF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")

ExternalProject_Add(TARGET_expat
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/expat-${VERSION_EXTERNAL}
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/expat-${VERSION_EXTERNAL}.tar.xz
                    URL_HASH SHA1=5178e13c1e34f4643d5118d5758babfe0e836fe2
                    PATCH_COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_BINARY_DIR}/expat-${VERSION_EXTERNAL}/src/TARGET_expat/doc ${CMAKE_CURRENT_BINARY_DIR}/expat-${VERSION_EXTERNAL}/src/TARGET_expat-build/doc
                    CMAKE_ARGS ${EXPAT_CMAKE_ARGS}
                    INSTALL_COMMAND ${CMAKE_MAKE_PROGRAM} install
)
