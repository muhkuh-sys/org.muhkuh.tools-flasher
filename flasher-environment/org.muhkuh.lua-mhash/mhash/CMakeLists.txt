CMAKE_MINIMUM_REQUIRED(VERSION 3.7)

PROJECT("module_mhash_lua")

# NOTE: this does not work with the "PROJECT" command. The version has too many elements.
SET(PROJECT_VERSION "0.9.9.9.9")

# Enable tests (see here for details: http://www.vtk.org/Wiki/CMake/Testing_With_CTest)
ENABLE_TESTING()

FIND_PACKAGE(SWIG REQUIRED)
INCLUDE(${SWIG_USE_FILE})

SET(MHASH_LIBRARY      "${CMAKE_BINARY_DIR}/install/dev/lib/libmhash.a")
SET(MHASH_INCLUDE_DIR  "${CMAKE_BINARY_DIR}/install/dev/include")

INCLUDE_DIRECTORIES(TARGET_module_mhash_lua ${CMAKE_CURRENT_SOURCE_DIR} ${LUA_INCLUDE_DIR} ${MHASH_INCLUDE_DIR})

# Build the Lua module.
SET_SOURCE_FILES_PROPERTIES(mhash.i PROPERTIES CPLUSPLUS ON)
SET_SOURCE_FILES_PROPERTIES(mhash.i PROPERTIES SWIG_FLAGS "-I${CMAKE_CURRENT_SOURCE_DIR} -I${MHASH_INCLUDE_DIR}")
SWIG_ADD_MODULE(TARGET_module_mhash_lua lua mhash.i mhash_state.cpp)
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	SWIG_LINK_LIBRARIES(TARGET_module_mhash_lua ${LUA_LIBRARIES} ${MHASH_LIBRARY})
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
SWIG_LINK_LIBRARIES(TARGET_module_mhash_lua ${MHASH_LIBRARY})

# The module depends on the Lua interpreter and libmhash.
ADD_DEPENDENCIES(TARGET_module_mhash_lua TARGET_lua54 TARGET_libmhash)

# Set the name of the output file to "mhash".
SET_TARGET_PROPERTIES(TARGET_module_mhash_lua PROPERTIES PREFIX "" OUTPUT_NAME "mhash")

# On mingw link all compiler libraries static.
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	SET_PROPERTY(TARGET TARGET_module_mhash_lua PROPERTY LINK_FLAGS "-static -static-libgcc -static-libstdc++")
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))

# Install the lua module.
INSTALL(TARGETS TARGET_module_mhash_lua DESTINATION ${FLASHER_PACKAGE_DIR}/lua_plugins)

# Add tests for this module.
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	# Here are the MinGW specific tests.
	ADD_TEST(NAME mhash_MinGW_DLL_dependencies
	         COMMAND "${PYTHON_EXECUTABLE}" ${CMAKE_HOME_DIRECTORY}/cmake/tests/mingw_dll_dependencies.py -u lua5.4 $<TARGET_FILE:TARGET_module_mhash_lua>)
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
