PROJECT("lua-archive")

# Enable tests (see here for details: http://www.vtk.org/Wiki/CMake/Testing_With_CTest)
ENABLE_TESTING()

SET(EXTERNAL_LIB_DIR "${CMAKE_BINARY_DIR}/install/dev/lib/")

INCLUDE_DIRECTORIES(${LUA_INCLUDE_DIR})
INCLUDE_DIRECTORIES(${CMAKE_BINARY_DIR}/swig_runtime)
INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR})
INCLUDE_DIRECTORIES(${CMAKE_BINARY_DIR}/install/dev/include)

IF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
	# libarchive has the suffix "_static" on Windows.
	SET(LIBARCHIVE_LIBRARY ${EXTERNAL_LIB_DIR}/libarchive_static.a)
	# No ACL on Windows.
	SET(ACL_LIB "")
ELSE(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
	SET(LIBARCHIVE_LIBRARY ${EXTERNAL_LIB_DIR}/libarchive.a)
	# ACL is part of the required packages in a standard Ubuntu system.
	SET(ACL_LIB "-lacl")
ENDIF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")

SET_SOURCE_FILES_PROPERTIES(archive.i PROPERTIES CPLUSPLUS ON)
SET_SOURCE_FILES_PROPERTIES(archive.i PROPERTIES SWIG_FLAGS "")
SWIG_ADD_MODULE(TARGET_archive lua archive.i wrapper.cpp)
SWIG_LINK_LIBRARIES(TARGET_archive ${LIBARCHIVE_LIBRARY} ${EXTERNAL_LIB_DIR}/libz.a ${EXTERNAL_LIB_DIR}/libbzip2.a ${EXTERNAL_LIB_DIR}/liblz4.a ${EXTERNAL_LIB_DIR}/liblzma.a ${EXTERNAL_LIB_DIR}/libzstd.a ${ACL_LIB})
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	SWIG_LINK_LIBRARIES(TARGET_archive ${LUA_LIBRARIES})
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
ADD_DEPENDENCIES(TARGET_archive TARGET_lua54 TARGET_libarchive TARGET_swigluarun)

# Set the name of the output file to "archive".
SET_TARGET_PROPERTIES(TARGET_archive PROPERTIES PREFIX "" OUTPUT_NAME "archive")

# On mingw link all compiler libraries static.
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	SET_PROPERTY(TARGET TARGET_archive PROPERTY LINK_FLAGS "-static-libgcc -static-libstdc++")
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))

# Install the lua module.
INSTALL(TARGETS TARGET_archive DESTINATION lua_plugins)

# Add tests for this module.
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	# Here are the MinGW specific tests.
	ADD_TEST(NAME archive_MinGW_DLL_dependencies
	         COMMAND "${PYTHON_EXECUTABLE}" ${CMAKE_HOME_DIRECTORY}/cmake/tests/mingw_dll_dependencies.py -u lua5.4 $<TARGET_FILE:TARGET_archive>)
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
