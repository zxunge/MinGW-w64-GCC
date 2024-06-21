#!/usr/bin/bash

set -eux

BUILDROOT=/home/gcc-build
ARCH=i686
EXCEPTIONS=dwarf
THREADS=posix
GCC_VERSION=10.5.0
RT_VERSION=7.0.0
REVNO=0
NAME=${ARCH}-${GCC_VERSION}-${THREADS}-${EXCEPTIONS}-rev${REVNO}

cp -rf * /home/
cd /home

wget -q https://github.com/brechtsanders/winlibs_mingw/releases/download/14.1.0posix-18.1.7-12.0.0-ucrt-r2/winlibs-i686-posix-dwarf-gcc-14.1.0-mingw-w64ucrt-12.0.0-r2.zip
unzip -q winlibs-i686-posix-dwarf-gcc-14.1.0-mingw-w64ucrt-12.0.0-r2.zip

git clone https://github.com/niXman/mingw-builds.git

cd mingw-builds
./build --mode=gcc-${GCC_VERSION}          \
        --arch=${ARCH}                     \
        --buildroot=${BUILDROOT}           \
        --exceptions=${EXCEPTIONS}         \
        --use-lto                          \
        --bootstrapall                     \
        --provided-toolchain=/home/mingw32/bin  \
        --rt-version=v${RT_VERSION}        \
        --with-default-msvcrt=ucrt         \
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
