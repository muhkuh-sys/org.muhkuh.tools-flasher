ADD_SUBDIRECTORY(bzip2)
ADD_SUBDIRECTORY(lz4)
ADD_SUBDIRECTORY(lzma)
ADD_SUBDIRECTORY(zlib)
ADD_SUBDIRECTORY(zstd)

# NOTE: Do not build libarchive with LZO. It's GPL license conflicts with the other packages.

ADD_SUBDIRECTORY(libarchive)
