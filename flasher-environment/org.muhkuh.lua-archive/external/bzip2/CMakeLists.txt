PROJECT("bzip2")

SET(VERSION_EXTERNAL "1.0.8")


#----------------------------------------------------------------------------
#
# Build the project.
#
SET(PRJ_CMAKE_ARGS "")

LIST(APPEND PRJ_CMAKE_ARGS "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
#LIST(APPEND PRJ_CMAKE_ARGS "-DPRJ_DIR=${PRJ_DIR}")
LIST(APPEND PRJ_CMAKE_ARGS "-DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/install/dev")
LIST(APPEND PRJ_CMAKE_ARGS "-DVERSION_EXTERNAL=${VERSION_EXTERNAL}")

ExternalProject_Add(TARGET_bzip2
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/bzip2-${VERSION_EXTERNAL}
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/bzip2-${VERSION_EXTERNAL}.tar.gz
                    URL_HASH SHA1=bf7badf7e248e0ecf465d33c2f5aeec774209227
                    PATCH_COMMAND "${PYTHON_INTERPRETER}" ${CMAKE_HOME_DIRECTORY}/cmake/tools/apply_patches.py --working-folder ${CMAKE_CURRENT_BINARY_DIR}/bzip2-${VERSION_EXTERNAL}/src/TARGET_bzip2 --copy-folder ${CMAKE_CURRENT_SOURCE_DIR}/copy_over
                    CMAKE_ARGS ${PRJ_CMAKE_ARGS}
                    INSTALL_COMMAND make install
)
