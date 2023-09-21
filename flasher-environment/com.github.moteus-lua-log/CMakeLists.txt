PROJECT("argparse")

SET(VERSION_EXTERNAL "0.1.6")


#----------------------------------------------------------------------------
#
# Extract the sources.
#

ExternalProject_Add(TARGET_lua_log
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/lua_log
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/lua-log-${VERSION_EXTERNAL}.tar.gz
                    URL_HASH SHA1=1e1b7a7d9a6ac669d89d12266096d3c2eb3eed32
                    CONFIGURE_COMMAND true
                    BUILD_COMMAND true
                    INSTALL_COMMAND true
)

INSTALL(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/lua_log/src/TARGET_lua_log/lua
        DESTINATION ${FLASHER_PACKAGE_DIR})
