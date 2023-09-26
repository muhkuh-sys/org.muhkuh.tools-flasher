cmake_minimum_required(VERSION 3.0)

# The version number is a combination of the LUA version and the packaging.
PROJECT("org.lua.lua-lua5.4"
	VERSION ${VERSION}
)


SET(CMAKE_SKIP_RPATH FALSE)
SET(CMAKE_SKIP_BUILD_RPATH FALSE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
set(CMAKE_BUILD_RPATH "$ORIGIN")
set(CMAKE_INSTALL_RPATH "$ORIGIN")


INCLUDE(CheckIncludeFiles)

# Enable tests (see here for details: http://www.vtk.org/Wiki/CMake/Testing_With_CTest)
ENABLE_TESTING()


#----------------------------------------------------------------------------
#
# Filter and compile the ressource files.
#

IF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
	SET(LUALIB_RC  ${CMAKE_CURRENT_BINARY_DIR}/lua_dll.rc)
	CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/lua_dll.rc  ${LUALIB_RC})

	SET(LUAEXE_RC  ${CMAKE_CURRENT_BINARY_DIR}/lua_exe.rc)
	CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/lua_exe.rc  ${LUAEXE_RC})
ELSE(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
	SET(LUALIB_RC  )
	SET(LUAEXE_RC  )
ENDIF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")


#----------------------------------------------------------------------------
#
# Find all headers and libraries.
#
CHECK_INCLUDE_FILES(readline/readline.h HAVE_READLINE_H)


#----------------------------------------------------------------------------
#
# Build the LUA shared object and executable.
#

SET(lua_SOURCES
	src/lapi.c
	src/lauxlib.c
	src/lbaselib.c
	src/lcode.c
	src/lcorolib.c
	src/lctype.c
	src/ldblib.c
	src/ldebug.c
	src/ldo.c
	src/ldump.c
	src/lfunc.c
	src/lgc.c
	src/linit.c
	src/liolib.c
	src/llex.c
	src/lmathlib.c
	src/lmem.c
	src/loadlib.c
	src/lobject.c
	src/lopcodes.c
	src/loslib.c
	src/lparser.c
	src/lstate.c
	src/lstring.c
	src/lstrlib.c
	src/ltable.c
	src/ltablib.c
	src/ltm.c
	src/luac.c
	src/lundump.c
	src/lutf8lib.c
	src/lvm.c
	src/lzio.c
)

SET(lua_HEADERS
	src/lapi.h
	src/lauxlib.h
	src/lcode.h
	src/lctype.h
	src/ldebug.h
	src/ldo.h
	src/lfunc.h
	src/lgc.h
	src/ljumptab.h
	src/llex.h
	src/llimits.h
	src/lmem.h
	src/lobject.h
	src/lopcodes.h
	src/lopnames.h
	src/lparser.h
	src/lprefix.h
	src/lstate.h
	src/lstring.h
	src/ltable.h
	src/ltm.h
	src/luaconf.h
	src/lua.h
	src/lua.hpp
	src/lualib.h
	src/lundump.h
	src/lvm.h
	src/lzio.h
)

ADD_LIBRARY(TARGET_lualib SHARED ${lua_SOURCES} ${LUALIB_RC})

ADD_EXECUTABLE(TARGET_luaexe
               src/lua.c
               ${LUAEXE_RC})

TARGET_INCLUDE_DIRECTORIES(TARGET_lualib
                           PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

SET(LUA_LIBS "")
IF(UNIX)
	IF(HAVE_READLINE_H)
		MESSAGE("Using readline...")
		TARGET_COMPILE_DEFINITIONS(TARGET_lualib
		                           PRIVATE LUA_USE_LINUX)
		TARGET_COMPILE_DEFINITIONS(TARGET_luaexe
		                           PRIVATE LUA_USE_LINUX LUA_USE_READLINE)
		LIST(APPEND LUA_LIBS "m")
		LIST(APPEND LUA_LIBS "dl")
		LIST(APPEND LUA_LIBS "readline")
	ELSE(HAVE_READLINE_H)
		MESSAGE("Not using readline...")
		TARGET_COMPILE_DEFINITIONS(TARGET_lualib
		                           PRIVATE LUA_USE_LINUX)
		LIST(APPEND LUA_LIBS "m")
		LIST(APPEND LUA_LIBS "dl")
	ENDIF(HAVE_READLINE_H)

		TARGET_COMPILE_DEFINITIONS(TARGET_lualib
		                           PRIVATE _GNU_SOURCE)
ELSE(UNIX)
	IF(WIN32)
		TARGET_COMPILE_DEFINITIONS(TARGET_lualib
		                           PRIVATE LUA_BUILD_AS_DLL)
	ENDIF(WIN32)
ENDIF(UNIX)

TARGET_LINK_LIBRARIES(TARGET_lualib
                      PUBLIC ${LUA_LIBS})

SET_TARGET_PROPERTIES(TARGET_lualib PROPERTIES
                      PREFIX ""
                      OUTPUT_NAME lua5.4
                      IMPORT_PREFIX "")


TARGET_LINK_LIBRARIES(TARGET_luaexe
                      PRIVATE TARGET_lualib)
SET_TARGET_PROPERTIES(TARGET_luaexe PROPERTIES
                      OUTPUT_NAME lua5.4)

INSTALL(TARGETS TARGET_luaexe TARGET_lualib
        EXPORT EXPORT_package
        LIBRARY DESTINATION .
        ARCHIVE DESTINATION dev/lib
        RUNTIME DESTINATION .
        INCLUDES DESTINATION dev/include/lua5.4)
INSTALL(FILES   ${lua_HEADERS}  DESTINATION dev/include/lua5.4)

# Add tests for this module.
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	# Here are the MinGW specific tests.
	ADD_TEST(NAME lua_MinGW_DLL_dependencies
	         COMMAND "${PYTHON_INTERPRETER}" ${CMAKE_DLL_TEST} -u lua5.4 $<TARGET_FILE:TARGET_luaexe> $<TARGET_FILE:TARGET_lualib>)
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))


#----------------------------------------------------------------------------
#
# Build the CMAKE package.
#
INCLUDE(CMakePackageConfigHelpers)

SET(INCLUDE_INSTALL_DIR dev/include/)
CONFIGURE_PACKAGE_CONFIG_FILE(
	cmake/config.cmake.in
	"${CMAKE_CURRENT_BINARY_DIR}/package/${PROJECT_NAME}-config.cmake"
	INSTALL_DESTINATION dev/cmake
	PATH_VARS INCLUDE_INSTALL_DIR
)

WRITE_BASIC_PACKAGE_VERSION_FILE(
	"${CMAKE_CURRENT_BINARY_DIR}/package/${PROJECT_NAME}-version.cmake"
	COMPATIBILITY ExactVersion
)

EXPORT(
	EXPORT EXPORT_package
	FILE "${CMAKE_CURRENT_BINARY_DIR}/package/${PROJECT_NAME}-targets.cmake"
	NAMESPACE ${PROJECT_NAME}::
)

INSTALL(
	EXPORT EXPORT_package
	FILE ${PROJECT_NAME}-targets.cmake
	NAMESPACE ${PROJECT_NAME}::
	DESTINATION dev/cmake
)
INSTALL(
	FILES "${CMAKE_CURRENT_BINARY_DIR}/package/${PROJECT_NAME}-config.cmake" "${CMAKE_CURRENT_BINARY_DIR}/package/${PROJECT_NAME}-version.cmake"
	DESTINATION dev/cmake
	COMPONENT Devel
)
