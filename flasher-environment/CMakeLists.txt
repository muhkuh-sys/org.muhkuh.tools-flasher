CMAKE_MINIMUM_REQUIRED(VERSION 3.0)

PROJECT("flasher-environment")

# Python is used for the firmware build script and some test scripts.
IF(CMAKE_VERSION VERSION_LESS 3.12.0)
	FIND_PACKAGE(PythonInterp 3 REQUIRED)
	SET(PYTHON_INTERPRETER "${PYTHON_EXECUTABLE}")
ELSE(CMAKE_VERSION VERSION_LESS 3.12.0)
	FIND_PACKAGE(Python3 REQUIRED COMPONENTS Interpreter)
	SET(PYTHON_INTERPRETER "${Python3_EXECUTABLE}")
ENDIF(CMAKE_VERSION VERSION_LESS 3.12.0)

#----------------------------------------------------------------------------
#
# Construct the host ID for the configure command.
#
IF(${CMAKE_CROSSCOMPILING})
	IF(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
		# Get the prefix of the compiler.
		GET_FILENAME_COMPONENT(GCC_BASENAME ${CMAKE_C_COMPILER} NAME)
		IF(GCC_BASENAME MATCHES "([^-]+-[^-]+-[^-]+)-gcc")
			SET(CONFIGURE_HOST "--host=${CMAKE_MATCH_1}")
		ELSE(GCC_BASENAME MATCHES "([^-]+-[^-]+-[^-]+)-gcc")
			MESSAGE(FATAL_ERROR "Failed to extract the compiler prefix from the C compiler ${CMAKE_C_COMPILER}")
		ENDIF(GCC_BASENAME MATCHES "([^-]+-[^-]+-[^-]+)-gcc")
	ELSE(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
		MESSAGE(FATAL_ERROR "Cross compiling detected, but not using GCC. This is currently not supported.")
	ENDIF(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
ELSE(${CMAKE_CROSSCOMPILING})
	SET(CONFIGURE_HOST "")
ENDIF(${CMAKE_CROSSCOMPILING})

# Set a common installation folder.
SET(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install")

INCLUDE(cmake/platform.cmake)
MESSAGE("Building for: ${JONCHKI_PLATFORM}")

#----------------------------------------------------------------------------

ADD_SUBDIRECTORY(org.lua-lua)
ADD_SUBDIRECTORY(com.github.hoelzro-lua-term)
ADD_SUBDIRECTORY(com.github.keplerproject-luafilesystem)
ADD_SUBDIRECTORY(com.github.lunarmodules-luaexpat)
ADD_SUBDIRECTORY(org.muhkuh.lua-archive)
ADD_SUBDIRECTORY(org.muhkuh.lua-mhash)

#----------------------------------------------------------------------------
