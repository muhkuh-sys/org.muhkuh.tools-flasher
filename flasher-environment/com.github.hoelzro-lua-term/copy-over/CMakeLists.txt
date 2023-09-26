CMAKE_MINIMUM_REQUIRED(VERSION 2.8)

PROJECT("lua_term_core")

ENABLE_TESTING()

# Build the Lua module.
ADD_LIBRARY(TARGET_core MODULE
            core.c)
TARGET_INCLUDE_DIRECTORIES(TARGET_core
                           PRIVATE ${LUA_INCLUDE_DIR})
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	TARGET_LINK_LIBRARIES(TARGET_core ${LUA_LIBRARIES})
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))

# Set the name of the output file to "core".
SET_TARGET_PROPERTIES(TARGET_core PROPERTIES PREFIX "" OUTPUT_NAME "core")

# On mingw link all compiler libraries static.
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	SET_PROPERTY(TARGET TARGET_core PROPERTY LINK_FLAGS "-static -static-libgcc -static-libstdc++")
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))

# Add tests for this module.
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	# Here are the MinGW specific tests.
	ADD_TEST(NAME core_MinGW_DLL_dependencies
	         COMMAND "${PYTHON_INTERPRETER}" ${TEST_SCRIPT_FOLDER}/mingw_dll_dependencies.py -u lua5.1 -u lua5.2 -u lua5.3 -u lua5.4 $<TARGET_FILE:TARGET_core>)
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
