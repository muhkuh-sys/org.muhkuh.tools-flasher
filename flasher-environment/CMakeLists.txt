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
