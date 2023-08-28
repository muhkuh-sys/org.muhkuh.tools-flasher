cmake_minimum_required(VERSION 3.7)

PROJECT("bzip2"
        VERSION ${VERSION_EXTERNAL})


#----------------------------------------------------------------------------
#
# Compile the sources.
#

SET(SOURCES_bzip2 blocksort.c
                  huffman.c
                  crctable.c
                  randtable.c
                  compress.c
                  decompress.c
                  bzlib.c)

ADD_LIBRARY(TARGET_bzip2 STATIC ${SOURCES_bzip2})

# This static library will be linked with a shared object later. Add "-fPIC" on GCC systems or X64 builds break.
IF("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU"  AND  "${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
	SET_TARGET_PROPERTIES(TARGET_bzip2 PROPERTIES COMPILE_FLAGS -fPIC)
ENDIF("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU"  AND  "${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")

# Set the name of the output file to "bzip2".
SET_TARGET_PROPERTIES(TARGET_bzip2 PROPERTIES OUTPUT_NAME "bzip2")

INSTALL(TARGETS TARGET_bzip2
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION bin
        INCLUDES DESTINATION include)
INSTALL(FILES bzlib.h DESTINATION include)
