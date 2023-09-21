PROJECT("argparse")

SET(VERSION_EXTERNAL "0.6.0")


#----------------------------------------------------------------------------
#
# Extract the sources.
#

ExternalProject_Add(TARGET_argparse
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/argparse
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/argparse-${VERSION_EXTERNAL}.tar.gz
                    URL_HASH SHA1=48dcb52e67179c01ea07de11af447c56d757de65
                    CONFIGURE_COMMAND true
                    BUILD_COMMAND true
                    INSTALL_COMMAND true
)

INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/argparse/src/TARGET_argparse/src/argparse.lua
        DESTINATION ${FLASHER_PACKAGE_DIR}/lua)
