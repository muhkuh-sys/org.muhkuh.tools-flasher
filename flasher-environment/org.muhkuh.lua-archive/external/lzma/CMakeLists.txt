PROJECT("lzma")

INCLUDE(ExternalProject)

SET(VERSION_EXTERNAL "5.4.3")


#----------------------------------------------------------------------------
#
# Build the project.
#
IF(${CMAKE_CROSSCOMPILING})
	IF("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
		# Get the prefix of the compiler.
		GET_FILENAME_COMPONENT(GCC_BASENAME ${CMAKE_C_COMPILER} NAME)
		IF(${GCC_BASENAME} MATCHES "([^-]+-[^-]+-[^-]+)-gcc")
			SET(CONFIGURE_HOST "--host=${CMAKE_MATCH_1}")
		ELSE(${GCC_BASENAME} MATCHES "([^-]+-[^-]+-[^-]+)-gcc")
			MESSAGE(FATAL_ERROR "Failed to extract the compiler prefix from the C compiler ${CMAKE_C_COMPILER}")
		ENDIF(${GCC_BASENAME} MATCHES "([^-]+-[^-]+-[^-]+)-gcc")
	ELSE("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
		MESSAGE(FATAL_ERROR "Cross compiling detected, but not using GCC. This is currently not supported by the CMake wrapper for OpenSSL.")
	ENDIF("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
ELSE(${CMAKE_CROSSCOMPILING})
	SET(CONFIGURE_HOST "")
ENDIF(${CMAKE_CROSSCOMPILING})


ExternalProject_Add(TARGET_xz
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/xz-${VERSION_EXTERNAL}
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/xz-${VERSION_EXTERNAL}.tar.xz
                    URL_HASH SHA1=d04e48be35a73fe4b99d6bd9bf7278b1b6293c7d
                    CONFIGURE_COMMAND ${CMAKE_CURRENT_BINARY_DIR}/xz-${VERSION_EXTERNAL}/src/TARGET_xz/configure --prefix=${CMAKE_BINARY_DIR}/install/dev --disable-assembler --enable-shared=no --enable-static=yes --with-pic --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-lzma-links --disable-scripts --disable-doc ${CONFIGURE_HOST}
                    BUILD_COMMAND make
                    INSTALL_COMMAND make install
)
