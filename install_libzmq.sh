#!/usr/bin/env bash
# script to install libzmq/libsodium for use in wheels
set -ex
CPU_COUNT=${CPU_COUNT:-4}
REPO="$PWD"
SHLIB_EXT=".so"
PREFIX="${ZMQ_PREFIX:-/tmp/zmq}"
LICENSE_DIR="$PREFIX/licenses"
test -d "$LICENSE_DIR" || mkdir -p "$LICENSE_DIR"

if [[ "$(uname)" == "Darwin" ]]; then
  SHLIB_EXT=".dylib"
  # make sure deployment target is set
  echo "${MACOSX_DEPLOYMENT_TARGET=}"
  test ! -z "${MACOSX_DEPLOYMENT_TARGET}"
  # need LT_MULTI_MODULE or libtool will strip out
  # all multi-arch symbols at the last step
  export LT_MULTI_MODULE=1
  ARCHS="x86_64 arm64"
  echo "building libzmq for mac ${ARCHS}"
  export CXX="${CXX:-clang++}"
  for arch in ${ARCHS}; do
    # seem to need ARCH in CXX for libtool
    export CXX="${CXX} -arch ${arch}"
    export CFLAGS="-arch ${arch} ${CFLAGS:-}"
    export CXXFLAGS="-arch ${arch} ${CXXFLAGS:-}"
    export LDFLAGS="-arch ${arch} ${LDFLAGS:-}"
  done
fi

if [ -f "$PREFIX/lib/libzmq${SHLIB_EXT}" ]; then
  echo "using $PREFIX/lib/libzmq${SHLIB_EXT}"
  exit 0
fi

# add rpath so auditwheel patches it
export LDFLAGS="${LDFLAGS} -Wl,-rpath,$PREFIX/lib"

curl -L -O "https://download.libsodium.org/libsodium/releases/libsodium-${LIBSODIUM_VERSION}-stable.tar.gz"

curl -L -O "https://github.com/zeromq/libzmq/releases/download/v${LIBZMQ_VERSION}/zeromq-${LIBZMQ_VERSION}.tar.gz"

tar -xzf libsodium-${LIBSODIUM_VERSION}*.tar.gz
cd libsodium-*/
./configure --prefix="$PREFIX"
make -j${CPU_COUNT}
make install
cp LICENSE "${LICENSE_DIR}/libsodium-LICENSE"
cd ..

which ldconfig && ldconfig || true

# make sure to find our libsodium
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig

tar -xzf zeromq-${LIBZMQ_VERSION}.tar.gz
cd zeromq-${LIBZMQ_VERSION}
cp LICENSE "${LICENSE_DIR}/libzmq-LICENSE"

# avoid error on warning
export CXXFLAGS="-Wno-error ${CXXFLAGS:-}"

./configure --prefix="$PREFIX" --disable-perf --without-docs --enable-curve --with-libsodium --disable-drafts --disable-libsodium_randombytes_close
# only build libzmq, not unused tests
make -j${CPU_COUNT} src/libzmq.la
make install-libLTLIBRARIES install-includeHEADERS

which ldconfig && ldconfig || true
