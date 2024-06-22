#!/usr/bin/bash

set -eux

BUILDROOT=/home/gcc-build
ARCH=i686
EXCEPTIONS=dwarf
THREADS=posix
GCC_VERSION=10.5.0
RT=ucrt
RT_VERSION=7.0.0
REVNO=0
NAME=${ARCH}-${GCC_VERSION}-${THREADS}-${EXCEPTIONS}-rev${REVNO}
TARGET=i686-w64-mingw32
ZSTD_VERSION=1.5.6
GMP_VERSION=6.2.1
MPFR_VERSION=4.2.1
MPC_VERSION=1.3.1
ISL_VERSION=0.26
EXPAT_VERSION=2.6.2
BINUTILS_VERSION=2.42
EXTRA_CRT_ARGS=--disable-lib64
EXTRA_GCC_ARGS="--disable-sjlj-exceptions --with-dwarf2"

mkdir -p /home/temp
cp -rf * /home/temp
cd /home/temp

BUILDTMP=$(cygpath -m /home/temp)

function get()
{
  mkdir -p ${SOURCE} && pushd ${SOURCE}
  FILE="${1##*/}"
  if [ ! -f "${FILE}" ]; then
    curl -fL "$1" -o ${FILE}
    case "${1##*.}" in
    gz|tgz)
      tar --warning=none -xzf ${FILE}
      ;;
    bz2)
      tar --warning=none -xjf ${FILE}
      ;;
    xz)
      tar --warning=none -xJf ${FILE}
      ;;
    zst)
      tar -I zstd -xf  ${FILE}
      ;;
    zip)
      unzip -q ${FILE}
      ;;
    *)
      exit 1
      ;;
    esac
  fi
  popd
}

# place where source code is downloaded & unpacked
SOURCE=/home/temp/source

# place where build for specific target is done
BUILD=/home/temp/build/${TARGET}

# place where build dependencies are installed
PREFIX=/home/temp/prefix/${TARGET}

# final installation folder
FINAL=/home/temp/${NAME}

# Toolchain used when compiling
wget -q https://github.com/brechtsanders/winlibs_mingw/releases/download/14.1.0${THREADS}-18.1.7-12.0.0-${RT}-r2/winlibs-${ARCH}-${THREADS}-${EXCEPTIONS}-gcc-14.1.0-mingw-w64${RT}-12.0.0-r2.zip
unzip -q winlibs-${ARCH}-${THREADS}-${EXCEPTIONS}-gcc-14.1.0-mingw-w64${RT}-12.0.0-r2.zip -d /

get https://github.com/facebook/zstd/archive/refs/tags/v${ZSTD_VERSION}.zip
get https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz
get https://ftp.gnu.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.gz
get https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz
get https://libisl.sourceforge.io/isl-${ISL_VERSION}.tar.gz
get https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VERSION//./_}/expat-${EXPAT_VERSION}.tar.xz
get https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz
get https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz
get https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v${RT_VERSION}.tar.bz2

FOLDER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

mkdir -p ${BUILD}/zstd && pushd ${BUILD}/zstd
cmake ${SOURCE}/zstd-${ZSTD_VERSION}/build/cmake \
  -G "Unix Makefiles"                            \
  -DCMAKE_BUILD_TYPE=Release                     \
  -DCMAKE_SYSTEM_NAME=Windows                    \
  -DCMAKE_INSTALL_PREFIX=${PREFIX}               \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER      \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY       \
  -DCMAKE_C_COMPILER=${TARGET}-gcc               \
  -DCMAKE_CXX_COMPILER=${TARGET}-g++             \
  -DZSTD_BUILD_STATIC=ON                         \
  -DZSTD_BUILD_SHARED=OFF                        \
  -DZSTD_BUILD_PROGRAMS=OFF                      \
  -DZSTD_BUILD_CONTRIB=OFF                       \
  -DZSTD_BUILD_TESTS=OFF
make -j$(nproc)
make install
popd

mkdir -p ${BUILD}/gmp && pushd ${BUILD}/gmp
${SOURCE}/gmp-${GMP_VERSION}/configure \
  --prefix=${PREFIX}                   \
  --host=${TARGET}                     \
  --disable-shared                     \
  --enable-static                      \
  --enable-fat
make -j$(nproc)
make install
popd

mkdir -p ${BUILD}/mpfr && pushd ${BUILD}/mpfr
${SOURCE}/mpfr-${MPFR_VERSION}/configure \
  --prefix=${PREFIX}                     \
  --host=${TARGET}                       \
  --disable-shared                       \
  --enable-static                        \
  --with-gmp-build=${BUILD}/gmp
make -j$(nproc)
make install
popd

mkdir -p ${BUILD}/mpc && pushd ${BUILD}/mpc
${SOURCE}/mpc-${MPC_VERSION}/configure \
  --prefix=${PREFIX}                   \
  --host=${TARGET}                     \
  --disable-shared                     \
  --enable-static                      \
  --with-{gmp,mpfr}=${PREFIX}
make -j$(nproc)
make install
popd

mkdir -p ${BUILD}/isl && pushd ${BUILD}/isl
${SOURCE}/isl-${ISL_VERSION}/configure \
  --prefix=${PREFIX}                   \
  --host=${TARGET}                     \
  --disable-shared                     \
  --enable-static                      \
  --with-gmp-prefix=${PREFIX}
make -j$(nproc)
make install
popd

mkdir -p ${BUILD}/expat && pushd ${BUILD}/expat
${SOURCE}/expat-${EXPAT_VERSION}/configure \
  --prefix=${PREFIX}                       \
  --host=${TARGET}                         \
  --disable-shared                         \
  --enable-static                          \
  --without-examples                       \
  --without-tests
make -j$(nproc)
make install
popd

mkdir -p ${BUILD}/binutils && pushd ${BUILD}/binutils
${SOURCE}/binutils-${BINUTILS_VERSION}/configure \
  --prefix=${FINAL}                              \
  --with-sysroot=${FINAL}                        \
  --host=${TARGET}                               \
  --target=${TARGET}                             \
  --enable-lto                                   \
  --enable-plugins                               \
  --enable-64-bit-bfd                            \
  --disable-multilib                             \
  --disable-werror                               \
  --with-{gmp,mpfr,mpc,isl}=${PREFIX}
make -j$(nproc)
make install
popd

mkdir -p ${BUILD}/mingw-w64-headers && pushd ${BUILD}/mingw-w64-headers
${SOURCE}/mingw-w64-v${RT_VERSION}/mingw-w64-headers/configure \
  --prefix=${FINAL}/${TARGET}                                     \
  --host=${TARGET}
make -j$(nproc)
make install
ln -sTf ${FINAL}/${TARGET} ${FINAL}/mingw
popd

mkdir -p ${BUILD}/mingw-w64-crt && pushd ${BUILD}/mingw-w64-crt
${SOURCE}/mingw-w64-v${RT_VERSION}/mingw-w64-crt/configure \
  --prefix=${FINAL}/${TARGET}                                 \
  --with-sysroot=${FINAL}/${TARGET}                           \
  --host=${TARGET}                                            \
  --disable-dependency-tracking                               \
  --enable-warnings=0                                         \
  ${EXTRA_CRT_ARGS}
make -j$(nproc)
make install
popd

mkdir -p ${BUILD}/gcc && pushd ${BUILD}/gcc
${SOURCE}/gcc-${GCC_VERSION}/configure \
  --prefix=${FINAL}                    \
  --with-sysroot=${FINAL}              \
  --target=${TARGET}                   \
  --host=${TARGET}                     \
  --disable-dependency-tracking        \
  --disable-multilib                   \
  --disable-werror                     \
  --enable-nls                         \
  --enable-shared                      \
  --enable-lto                         \
  --enable-languages=c,c++,lto,fortran,d \
  --enable-libgomp                     \
  --enable-threads=posix               \
  --enable-checking=release            \
  --enable-mingw-wildcard              \
  --enable-large-address-aware         \
  --disable-libstdcxx-pch              \
  --disable-libstdcxx-verbose          \
  --disable-win32-registry             \
  --with-tune=intel                    \
  ${EXTRA_GCC_ARGS}                    \
  --with-{gmp,mpfr,mpc,isl,zstd}=${PREFIX}
make -j$(nproc)
make install
popd

mkdir -p ${BUILD}/mingw-w64-winpthreads && pushd ${BUILD}/mingw-w64-winpthreads
${SOURCE}/mingw-w64-v${RT_VERSION}/mingw-w64-libraries/winpthreads/configure \
  --prefix=${FINAL}/${TARGET}                                                   \
  --with-sysroot=${FINAL}/${TARGET}                                             \
  --host=${TARGET}                                                              \
  --disable-dependency-tracking                                                 \
  --enable-shared
make -j$(nproc)
make install
popd

find ${FINAL} -name '*.exe' -print0 | xargs -0 -n 8 -P 2 ${TARGET}-strip --strip-unneeded
find ${FINAL} -name '*.dll' -print0 | xargs -0 -n 8 -P 2 ${TARGET}-strip --strip-unneeded
find ${FINAL} -name '*.o'   -print0 | xargs -0 -n 8 -P 2 ${TARGET}-strip --strip-unneeded
find ${FINAL} -name '*.a'   -print0 | xargs -0 -n 8 -P `nproc` ${TARGET}-strip --strip-unneeded

rm ${FINAL}/mingw
7zr a -mx9 -mqs=on -mmt=on ${BUILDTMP}/${NAME}.7z ${FINAL}

if [[ -v GITHUB_WORKFLOW ]]; then
  echo "OUTPUT_BINARY=${BUILDTMP}/${NAME}.7z" >> $GITHUB_OUTPUT
  echo "RELEASE_NAME=${NAME}" >> $GITHUB_OUTPUT
  echo "GCC_VERSION=${GCC_VERSION}" >> $GITHUB_OUTPUT
  echo "MINGW_VERSION=${RT_VERSION}" >> $GITHUB_OUTPUT
  echo "OUTPUT_NAME=${NAME}.7z" >> $GITHUB_OUTPUT
fi
