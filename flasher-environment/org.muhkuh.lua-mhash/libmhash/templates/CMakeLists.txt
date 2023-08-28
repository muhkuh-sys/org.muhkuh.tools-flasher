cmake_minimum_required(VERSION 3.2.3) #required for TARGET_INCLUDE_DIRECTORIES

PROJECT("libmhash"
        VERSION ${VERSION_EXTERNAL})

INCLUDE(CheckIncludeFiles)
INCLUDE(CheckFunctionExists)
INCLUDE(CheckLibraryExists)
INCLUDE(CheckStructHasMember)
INCLUDE(CheckTypeSize)


#----------------------------------------------------------------------------
#
# Get all defines for config.h.in .
#
SET(ENABLE_ADLER32        1)
SET(ENABLE_CRC32          1)
SET(ENABLE_GOST           1)
SET(ENABLE_HAVAL          1)
SET(ENABLE_MD2            1)
SET(ENABLE_MD4            1)
SET(ENABLE_MD5            1)
SET(ENABLE_RIPEMD         1)
SET(ENABLE_SHA1           1)
SET(ENABLE_SHA256_SHA224  1)
SET(ENABLE_SHA512_SHA384  1)
SET(ENABLE_SNEFRU         1)
SET(ENABLE_TIGER          1)
SET(ENABLE_WHIRLPOOL      1)
SET(ENABLE_HILROM         1)
SET(ENABLE_CRC16          1)

CHECK_INCLUDE_FILES(assert.h HAVE_ASSERT_H)
CHECK_INCLUDE_FILES(byteswap.h HAVE_BYTESWAP_H)
CHECK_INCLUDE_FILES(ctype.h HAVE_CTYPE_H)
CHECK_INCLUDE_FILES(dlfcn.h HAVE_DLFCN_H)
CHECK_INCLUDE_FILES(endian.h HAVE_ENDIAN_H)
CHECK_INCLUDE_FILES(errno.h HAVE_ERRNO_H)
CHECK_INCLUDE_FILES(fcntl.h HAVE_FCNTL_H)
CHECK_INCLUDE_FILES(inttypes.h HAVE_INTTYPES_H)
CHECK_INCLUDE_FILES(limits.h HAVE_LIMITS_H)
CHECK_INCLUDE_FILES(malloc.h HAVE_MALLOC_H)
CHECK_INCLUDE_FILES(memory.h HAVE_MEMORY_H)
CHECK_INCLUDE_FILES(signal.h HAVE_SIGNAL_H)
CHECK_INCLUDE_FILES(stdbool.h HAVE_STDBOOL_H)
CHECK_INCLUDE_FILES(stdint.h HAVE_STDINT_H)
CHECK_INCLUDE_FILES(stdio.h HAVE_STDIO_H)
CHECK_INCLUDE_FILES(stdlib.h HAVE_STDLIB_H)
CHECK_INCLUDE_FILES(strings.h HAVE_STRINGS_H)
CHECK_INCLUDE_FILES(string.h HAVE_STRING_H)
CHECK_INCLUDE_FILES(sys/endian.h HAVE_SYS_ENDIAN_H)
CHECK_INCLUDE_FILES(sys/mman.h HAVE_SYS_MMAN_H)
CHECK_INCLUDE_FILES(sys/stat.h HAVE_SYS_STAT_H)
CHECK_INCLUDE_FILES(sys/types.h HAVE_SYS_TYPES_H)
CHECK_INCLUDE_FILES(unistd.h HAVE_UNISTD_H)
CHECK_INCLUDE_FILES(utime.h HAVE_UTIME_H)
CHECK_INCLUDE_FILES(values.h HAVE_VALUES_H)

CHECK_FUNCTION_EXISTS(bcopy HAVE_BCOPY)
CHECK_FUNCTION_EXISTS(bzero HAVE_BZERO)
CHECK_FUNCTION_EXISTS(fcntl HAVE_FCNTL)
CHECK_FUNCTION_EXISTS(fsync HAVE_FSYNC)
#CHECK_LIBRARY_EXISTS(dmalloc HAVE_LIBDMALLOC)
CHECK_FUNCTION_EXISTS(lstat HAVE_LSTAT)
IF(${CMAKE_COMPILER_IS_GNUCC})
	SET(HAVE_MALLOC 1)
ENDIF(${CMAKE_COMPILER_IS_GNUCC})
CHECK_FUNCTION_EXISTS(memmove HAVE_MEMMOVE)
CHECK_FUNCTION_EXISTS(memset HAVE_MEMSET)
CHECK_FUNCTION_EXISTS(mlock HAVE_MLOCK)
CHECK_FUNCTION_EXISTS(readdir HAVE_READDIR)
CHECK_FUNCTION_EXISTS(readdir_r HAVE_READDIR_R)
CHECK_FUNCTION_EXISTS(sigaction HAVE_SIGACTION)
CHECK_FUNCTION_EXISTS(signal HAVE_SIGNAL)
CHECK_FUNCTION_EXISTS(stat HAVE_STAT)
CHECK_FUNCTION_EXISTS(strtol HAVE_STRTOL)
CHECK_FUNCTION_EXISTS(umask HAVE_UMASK)
CHECK_FUNCTION_EXISTS(utime HAVE_UTIME)
CHECK_TYPE_SIZE("_Bool" HAVE__BOOL)

SET(PACKAGE "mhash")
SET(PACKAGE_BUGREPORT "mhash-devel@sourceforge.net")
SET(PACKAGE_NAME "MHASH")
SET(PACKAGE_STRING "MHASH 0.9.9")
SET(PACKAGE_TARNAME "mhash")
SET(PACKAGE_VERSION "0.9.9")
SET(VERSION "0.9.9")

# We are not on AIX.
SET(DEFINE__ALL_SOURCE "/* # undef _ALL_SOURCE */")

IF(${CMAKE_COMPILER_IS_GNUCC})
	SET(DEFINE__GNU_SOURCE "# define _GNU_SOURCE 1")
	SET(PROTOTYPES 1)
	SET(__PROTOTYPES 1)
	SET(STDC_HEADERS 1)
ELSE(${CMAKE_COMPILER_IS_GNUCC})
	SET(DEFINE__GNU_SOURCE "/* # undef _GNU_SOURCE */")
ENDIF(${CMAKE_COMPILER_IS_GNUCC})

CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/mhash_config.h.in ${CMAKE_CURRENT_SOURCE_DIR}/include/mutils/mhash_config.h)
#CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/mhash_config.h.in ${CMAKE_CURRENT_SOURCE_DIR}/config.h)


#-----------------------------------------------------------------------------
#
# Build the mhash library.
#
set(mhash_SOURCES
	lib/adler32.c
	lib/crc16.c
	lib/crc32.c
	lib/gosthash.c
	lib/haval.c
	lib/hilrom.c
	lib/keygen.c
	lib/keygen_asis.c
	lib/keygen_hex.c
	lib/keygen_mcrypt.c
	lib/keygen_s2k.c
	lib/md2.c
	lib/md4.c
	lib/md5.c
	lib/mhash.c
	lib/ripemd.c
	lib/sha1.c
	lib/sha256.c
	lib/sha256_sha224.c
	lib/sha512_sha384.c
	lib/snefru.c
	lib/stdfns.c
	lib/tiger.c
	lib/tiger_sboxes.c
	lib/whirlpool.c
)

set(mhash_HEADERS
	include/mhash.h
	include/mutils/mglobal.h
	include/mutils/mhash.h
	include/mutils/mincludes.h
	include/mutils/mtypes.h
	include/mutils/mutils.h
	lib/keygen.h
	lib/libdefs.h
	lib/mhash_adler32.h
	lib/mhash_crc16.h
	lib/mhash_crc32.h
	lib/mhash_gost.h
	lib/mhash_haval.h
	lib/mhash_hilrom.h
	lib/mhash_int.h
	lib/mhash_md2.h
	lib/mhash_md4.h
	lib/mhash_md5.h
	lib/mhash_ripemd.h
	lib/mhash_sha1.h
	lib/mhash_sha256.h
	lib/mhash_sha256_sha224.h
	lib/mhash_sha512_sha384.h
	lib/mhash_snefru.h
	lib/mhash_tiger.h
	lib/mhash_whirlpool.h
)

# Build the library.
ADD_LIBRARY(TARGET_mhash STATIC ${mhash_SOURCES})
#TARGET_INCLUDE_DIRECTORIES(mhash_lib PUBLIC include lib)
INCLUDE_DIRECTORIES(TARGET_mhash PUBLIC include lib)

SET_TARGET_PROPERTIES(TARGET_mhash PROPERTIES
                      OUTPUT_NAME mhash)

# This static library will be linked with a shared object later. Add "-fPIC" on GCC systems or X64 builds break.
IF("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU"  AND  "${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
	SET_TARGET_PROPERTIES(TARGET_mhash PROPERTIES COMPILE_FLAGS -fPIC)
ENDIF("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU"  AND  "${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")


#-----------------------------------------------------------------------------
#
# Install all components of the library.
# This is the library itself and the public headers.
#
INSTALL(TARGETS TARGET_mhash
        EXPORT EXPORT_package
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION bin
        INCLUDES DESTINATION include)
INSTALL(FILES include/mhash.h
        DESTINATION include)
INSTALL(FILES include/mutils/mglobal.h include/mutils/mhash.h include/mutils/mhash_config.h include/mutils/mincludes.h include/mutils/mtypes.h include/mutils/mutils.h
        DESTINATION include/mutils)
