set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR riscv64)

# set VERBOSE if needed
# Source https://stackoverflow.com/questions/2670121/using-cmake-with-gnu-make-how-can-i-see-the-exact-commands
#set(CMAKE_VERBOSE_MAKEFILE ON)

set(PKGBASE ${WORKING_DIR}/packages)

set(tools /usr/bin)
set(CMAKE_C_COMPILER ${tools}/riscv64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER ${tools}/riscv64-linux-gnu-g++)

# Source: https://stackoverflow.com/questions/11423313/cmake-cross-compiling-c-flags-from-toolchain-file-ignored
UNSET(CMAKE_C_FLAGS CACHE)
UNSET(CMAKE_CXX_FLAGS CACHE)
set(CMAKE_C_FLAGS "-I${PKGBASE}/usr/include/ -L${PKGBASE}/usr/lib/riscv64-linux-gnu/ -L${PKGBASE}/lib/riscv64-linux-gnu/ -Xlinker -rpath=${PKGBASE}/lib/riscv64-linux-gnu/" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS "-I${PKGBASE}/usr/include/ -L${PKGBASE}/usr/lib/riscv64-linux-gnu/ -L${PKGBASE}/lib/riscv64-linux-gnu/ -Xlinker -rpath=${PKGBASE}/lib/riscv64-linux-gnu/" CACHE STRING "" FORCE)
