set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

# set VERBOSE if needed
# Source https://stackoverflow.com/questions/2670121/using-cmake-with-gnu-make-how-can-i-see-the-exact-commands
#set(CMAKE_VERBOSE_MAKEFILE ON)

set(PKGBASE ${WORKING_DIR}/packages)

set(tools /usr/bin)
set(CMAKE_C_COMPILER ${tools}/arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER ${tools}/arm-linux-gnueabihf-g++)

# Source: https://stackoverflow.com/questions/11423313/cmake-cross-compiling-c-flags-from-toolchain-file-ignored
UNSET(CMAKE_C_FLAGS CACHE)
UNSET(CMAKE_CXX_FLAGS CACHE)
set(CMAKE_C_FLAGS "-I${PKGBASE}/usr/include/ -L${PKGBASE}/usr/lib/arm-linux-gnueabihf/ -L${PKGBASE}/lib/arm-linux-gnueabihf/ -Xlinker -rpath=${PKGBASE}/lib/arm-linux-gnueabihf/" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS "-I${PKGBASE}/usr/include/ -L${PKGBASE}/usr/lib/arm-linux-gnueabihf/ -L${PKGBASE}/lib/arm-linux-gnueabihf/ -Xlinker -rpath=${PKGBASE}/lib/arm-linux-gnueabihf/" CACHE STRING "" FORCE)
