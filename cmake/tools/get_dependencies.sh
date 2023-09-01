#! /bin/bash

PKG_DIR=$(pwd)
apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --no-pre-depends $@ | grep "^\w")
find . -name "*.deb" -exec dpkg-deb --extract '{}' . \;
ALLLINKS=$(find . -xtype l)
for LINK in ${ALLLINKS}
do
	TARGET=$(readlink ${LINK})
	if [ ! -f ${TARGET} ]; then
		echo "Updating symlink ${LINK} to ${PKG_DIR}${TARGET}"
		ln -fs ${PKG_DIR}${TARGET} ${LINK}
	fi
done

# Remove any local installed versions of libc and libpthread. These libs are
# shipped with the compiler. Local versions in the "packages" folder might
# conflict with the compiler builtins.
find . -name "libc[._]*" -delete
find . -name "libpthread.*" -delete
find . -name "stdio.h" -delete
find . -name "math.h" -delete
find . -name "signal.h" -delete
