PROJECT("argparse")

SET(VERSION_EXTERNAL "2.2")


#----------------------------------------------------------------------------
#
# Extract the sources.
#

ExternalProject_Add(TARGET_date
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/date
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/date-version_${VERSION_EXTERNAL}.tar.gz
                    URL_HASH SHA1=8db5e32b67505e78d9dbb2e7931d215a3fce9ff8
                    CONFIGURE_COMMAND true
                    BUILD_COMMAND true
                    INSTALL_COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/date/src/TARGET_date/src/date.lua ${CMAKE_BINARY_DIR}/install/lua/
)
