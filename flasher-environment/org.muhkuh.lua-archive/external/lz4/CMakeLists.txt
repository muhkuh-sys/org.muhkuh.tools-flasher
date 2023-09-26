PROJECT("lz4")

SET(VERSION_EXTERNAL "1.9.4")


#----------------------------------------------------------------------------
#
# Build the project.
#
SET(PRJ_CMAKE_ARGS "")

LIST(APPEND PRJ_CMAKE_ARGS "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
LIST(APPEND PRJ_CMAKE_ARGS "-DPRJ_DIR=${PRJ_DIR}")
LIST(APPEND PRJ_CMAKE_ARGS "-DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/install/dev")

LIST(APPEND PRJ_CMAKE_ARGS "-DBUILD_SHARED_LIBS=OFF")
LIST(APPEND PRJ_CMAKE_ARGS "-DBUILD_STATIC_LIBS=ON")
LIST(APPEND PRJ_CMAKE_ARGS "-DLZ4_POSITION_INDEPENDENT_LIB=ON")


ExternalProject_Add(TARGET_lz4
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/lz4-${VERSION_EXTERNAL}
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/lz4-${VERSION_EXTERNAL}.tar.gz
                    URL_HASH SHA1=1d262fd78a0dbaa409e764979c6a643d0370f8d1
                    PATCH_COMMAND "${PYTHON_INTERPRETER}" ${CMAKE_HOME_DIRECTORY}/cmake/tools/apply_patches.py --working-folder ${CMAKE_CURRENT_BINARY_DIR}/lz4-${VERSION_EXTERNAL}/src/TARGET_lz4 --copy-folder ${CMAKE_CURRENT_SOURCE_DIR}/copy_over
                    SOURCE_SUBDIR contrib/cmake_unofficial
                    CMAKE_ARGS ${PRJ_CMAKE_ARGS}
                    INSTALL_COMMAND make install
)
