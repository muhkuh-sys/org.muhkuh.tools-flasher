PROJECT("lzma")

SET(VERSION_EXTERNAL "5.4.3")


#----------------------------------------------------------------------------
#
# Build the project.
#
ExternalProject_Add(TARGET_xz
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/xz-${VERSION_EXTERNAL}
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/xz-${VERSION_EXTERNAL}.tar.xz
                    URL_HASH SHA1=d04e48be35a73fe4b99d6bd9bf7278b1b6293c7d
                    CONFIGURE_COMMAND ${CMAKE_CURRENT_BINARY_DIR}/xz-${VERSION_EXTERNAL}/src/TARGET_xz/configure --prefix=${CMAKE_BINARY_DIR}/install/dev --disable-assembler --enable-shared=no --enable-static=yes --with-pic --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-lzma-links --disable-scripts --disable-doc ${CONFIGURE_HOST}
                    BUILD_COMMAND make
                    INSTALL_COMMAND make install
)
