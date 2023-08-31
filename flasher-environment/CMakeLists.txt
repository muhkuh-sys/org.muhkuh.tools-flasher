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

INCLUDE(ExternalProject)

# Add a custom target for the swig runtime for LUA.
FIND_PACKAGE(SWIG REQUIRED)
INCLUDE(${SWIG_USE_FILE})
INCLUDE(cmake/muhkuh_swig_lua_runtime.cmake)

#----------------------------------------------------------------------------

# Add the Lua interpreter first. It is referenced in all plugins.
ADD_SUBDIRECTORY(org.lua-lua)

# Add libusb which is a common build requirement for openocd and romloader.
ADD_SUBDIRECTORY(libusb)

# Add plugins
ADD_SUBDIRECTORY(com.github.hoelzro-lua-term)
ADD_SUBDIRECTORY(com.github.keplerproject-luafilesystem)
ADD_SUBDIRECTORY(com.github.lunarmodules-luaexpat)
ADD_SUBDIRECTORY(org.muhkuh.lua-archive)
ADD_SUBDIRECTORY(org.muhkuh.lua-mhash)

#----------------------------------------------------------------------------
#
# Build the openocd shared object. It is a dependency for the romloader plugin.
#

ADD_SUBDIRECTORY(org.openocd-openocd/external/openocd)
SET(OPENOCD_SO_INSTALL lua_plugins/openocd)
ADD_SUBDIRECTORY(org.openocd-openocd/openocd)

# Build the romloader plugins.
SET(PLUGINS_SOURCES_DIR "${CMAKE_HOME_DIRECTORY}/org.muhkuh.lua-romloader/targets/plugins")
SET(TARGET_LIBUSB TARGET_libusb)
SET(TARGET_LUA TARGET_lua54)
SET(INSTALL_DIR_LUA_MODULES lua_plugins)
ADD_SUBDIRECTORY(org.muhkuh.lua-romloader/plugins)
