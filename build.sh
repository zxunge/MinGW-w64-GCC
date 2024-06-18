#!/usr/bin/bash

set -eux

BUILDROOT=/home/gcc-build
ARCH=i686
EXCEPTIONS=dwarf
THREADS=posix
GCC_VERSION=13.2.0
RT_VERSION=10
REVNO=0
NAME=${ARCH}-${GCC_VERSION}-${THREADS}-${EXCEPTIONS}-rev${REVNO}

cp -rf * /home/
cd /home
rm -rf /mingw32
rm -rf /c/mingw64/bin

git clone https://github.com/niXman/mingw-builds.git

cd mingw-builds
./build --mode=gcc-${GCC_VERSION}          \
        --arch=${ARCH}                     \
        --buildroot=${BUILDROOT}           \
        --exceptions=${EXCEPTIONS}         \
        --use-lto                          \
        --dyn-deps                         \
        --rt-version=v${RT_VERSION}        \
        --rev=${REVNO}                     \
        --threads=${THREADS}               \
        --enable-languages=c,c++,fortran

7zr a -mx9 -mqs=on -mmt=on /home/${NAME}.7z ${BUILDROOT}/${ARCH}-${GCC_VERSION}-release-${THREADS}-${EXCEPTIONS}-rev${REVNO}/archives/*

if [[ -v GITHUB_WORKFLOW ]]; then
  echo "OUTPUT_BINARY=${HOME}/${NAME}.7z" >> $GITHUB_OUTPUT
  echo "RELEASE_NAME=${NAME}" >> $GITHUB_OUTPUT
  echo "GCC_VERSION=${GCC_VERSION_VERSION}" >> $GITHUB_OUTPUT
  echo "MINGW_VERSION=${RT_VERSION}" >> $GITHUB_OUTPUT
  echo "OUTPUT_NAME=${NAME}.7z" >> $GITHUB_OUTPUT
fi
