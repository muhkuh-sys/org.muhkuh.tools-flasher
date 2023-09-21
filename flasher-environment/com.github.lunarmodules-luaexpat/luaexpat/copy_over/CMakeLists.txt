cmake_minimum_required(VERSION 3.8)

PROJECT("com.github.lunarmodules-luaexpat")

ENABLE_TESTING()

#-----------------------------------------------------------------------------
#
# Build the LUA expat module.
#
ADD_LIBRARY(TARGET_luaexpat MODULE
            src/lxplib.c)

# Add the LUA includes and library.
TARGET_INCLUDE_DIRECTORIES(TARGET_luaexpat
                           PRIVATE ${LUA_INCLUDE_DIR})
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	TARGET_LINK_LIBRARIES(TARGET_luaexpat
	                      PRIVATE ${LUA_LIBRARIES})
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))

# Add the expat includes and library.
TARGET_INCLUDE_DIRECTORIES(TARGET_luaexpat
                           PRIVATE ${LIBEXPAT_INCLUDE_DIRECTORIES})
TARGET_LINK_LIBRARIES(TARGET_luaexpat
                      PRIVATE ${LIBEXPAT_LIBRARY})

# On MinGW link all compiler libraries static.
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	SET_PROPERTY(TARGET TARGET_luaexpat PROPERTY LINK_FLAGS "-static-libgcc -static-libstdc++")
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))

# Set the name of the output file to "lxp" without any prefix like "lib".
SET_TARGET_PROPERTIES(TARGET_luaexpat PROPERTIES PREFIX "" OUTPUT_NAME "lxp")


#-----------------------------------------------------------------------------
#
# Add tests for the modules.
#
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	# Here are the MinGW specific tests.
	ADD_TEST(NAME luaexpat_MinGW_DLL_dependencies
	         COMMAND "${PYTHON_INTERPRETER}" ${TEST_SCRIPT_FOLDER}/mingw_dll_dependencies.py -u lua5.1 -u lua5.2 -u lua5.3 -u lua5.4 $<TARGET_FILE:TARGET_luaexpat>)
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
