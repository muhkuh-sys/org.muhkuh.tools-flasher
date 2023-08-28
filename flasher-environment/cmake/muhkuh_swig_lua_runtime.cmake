#----------------------------------------------------------------------------
#
# Add a custom target for the swig runtime includes.
# The runtimes are generated during the build process by running the swig
# executable.
#

# Create a new directory for the swig runtime.
SET(SWIG_RUNTIME_OUTPUT_PATH ${CMAKE_BINARY_DIR}/swig_runtime)
MAKE_DIRECTORY(${SWIG_RUNTIME_OUTPUT_PATH})

# TODO: Replace this and all other custom commands with ExternalProject ?
ADD_CUSTOM_TARGET(TARGET_swigluarun ALL
                  COMMAND "${SWIG_EXECUTABLE}" -lua -external-runtime ${SWIG_RUNTIME_OUTPUT_PATH}/swigluarun.h
                  COMMENT "Build the swig lua runtime header."
                  BYPRODUCTS ${SWIG_RUNTIME_OUTPUT_PATH}/swigluarun.h
                  VERBATIM
)
