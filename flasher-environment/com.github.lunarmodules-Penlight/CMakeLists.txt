PROJECT("penlight")

SET(VERSION_EXTERNAL "1.13.1")


#----------------------------------------------------------------------------
#
# Extract the sources.
#

ExternalProject_Add(TARGET_penlight
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/penlight
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/Penlight-${VERSION_EXTERNAL}.tar.gz
                    URL_HASH SHA1=0897cebc12325ad5eebe1eeaa1c211dde414bffc
                    CONFIGURE_COMMAND true
                    BUILD_COMMAND true
                    INSTALL_COMMAND true

)

INSTALL(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/penlight/src/TARGET_penlight/lua
        DESTINATION ${FLASHER_PACKAGE_DIR})
