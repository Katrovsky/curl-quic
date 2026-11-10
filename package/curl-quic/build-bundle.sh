#!/usr/bin/env bash
#
# Build script for curl-quic:
# Builds QuicTLS, nghttp3, ngtcp2 as static libraries and statically links them into curl.
#
set -euo pipefail

echo "=================================================="
echo "== Building curl-quic with HTTP/3 (QUIC) support =="
echo "=================================================="

WORK_DIR="${BUILD_DIR:-$(pwd)}"
DEPS_DIR="${WORK_DIR}/deps-install"
SRC_DEPS="${WORK_DIR}/deps-src"
DESTDIR="${DESTDIR:-}"
PREFIX="${PREFIX:-/usr}"

mkdir -p "${DEPS_DIR}" "${SRC_DEPS}"

# Parallel jobs
NPROC=$(nproc 2>/dev/null || echo 2)

echo "Toolchain settings:"
echo "  CC:      ${CC:-gcc}"
echo "  CXX:     ${CXX:-g++}"
echo "  AR:      ${AR:-ar}"
echo "  RANLIB:  ${RANLIB:-ranlib}"
echo "  STRIP:   ${STRIP:-strip}"
echo "  HOST:    ${HOST:-}"
echo "  PREFIX:  ${PREFIX}"
echo "  DESTDIR: ${DESTDIR}"
echo "  JOBS:    ${NPROC}"

# Ensure toolchain directories are in PATH
if [[ "${CC}" == *"/"* ]]; then
    export PATH="$(dirname "${CC}"):${PATH}"
fi

export AR="${AR:-ar}"
export RANLIB="${RANLIB:-ranlib}"

# 1. Build QuicTLS (OpenSSL fork with QUIC APIs)
QUICTLS_DIR="${SRC_DEPS}/quictls"
if [ ! -f "${DEPS_DIR}/quictls/lib/libssl.a" ] && [ ! -f "${DEPS_DIR}/quictls/lib64/libssl.a" ]; then
    echo "--> [1/4] Building QuicTLS..."
    mkdir -p "${QUICTLS_DIR}"
    tar -xf "${DL_DIR}/openssl-3.1.5-quic1.tar.gz" --strip-components=1 -C "${QUICTLS_DIR}"

    pushd "${QUICTLS_DIR}" > /dev/null
    ./Configure linux-aarch64 \
        --prefix="${DEPS_DIR}/quictls" \
        --openssldir="${DEPS_DIR}/quictls/ssl" \
        no-shared \
        no-tests \
        no-deprecated
    make -j"${NPROC}"
    DESTDIR="" make install_sw
    popd > /dev/null
    echo "--> QuicTLS installed to ${DEPS_DIR}/quictls"
else
    echo "--> [1/4] QuicTLS already built, skipping."
fi

# Locate QuicTLS lib dir (lib or lib64)
if [ -d "${DEPS_DIR}/quictls/lib64" ]; then
    QUICTLS_LIBDIR="${DEPS_DIR}/quictls/lib64"
else
    QUICTLS_LIBDIR="${DEPS_DIR}/quictls/lib"
fi

# 2. Build nghttp3
NGHTTP3_DIR="${SRC_DEPS}/nghttp3"
if [ ! -f "${DEPS_DIR}/nghttp3/lib/libnghttp3.a" ] && [ ! -f "${DEPS_DIR}/nghttp3/lib64/libnghttp3.a" ]; then
    echo "--> [2/4] Building nghttp3..."
    mkdir -p "${NGHTTP3_DIR}"
    tar -xf "${DL_DIR}/nghttp3-1.8.0.tar.xz" --strip-components=1 -C "${NGHTTP3_DIR}"

    mkdir -p "${NGHTTP3_DIR}/build"
    pushd "${NGHTTP3_DIR}/build" > /dev/null
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="${DEPS_DIR}/nghttp3" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_C_COMPILER="${CC}" \
        -DCMAKE_AR="$(which "${AR}" || echo "${AR}")" \
        -DCMAKE_RANLIB="$(which "${RANLIB}" || echo "${RANLIB}")" \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -DENABLE_LIB_ONLY=ON \
        -DENABLE_STATIC_LIB=ON \
        -DENABLE_SHARED_LIB=OFF \
        -DCMAKE_BUILD_TYPE=Release
    cmake --build . -j"${NPROC}"
    DESTDIR="" cmake --install .
    popd > /dev/null
    echo "--> nghttp3 installed to ${DEPS_DIR}/nghttp3"
else
    echo "--> [2/4] nghttp3 already built, skipping."
fi

if [ -d "${DEPS_DIR}/nghttp3/lib64" ]; then
    NGHTTP3_LIBDIR="${DEPS_DIR}/nghttp3/lib64"
else
    NGHTTP3_LIBDIR="${DEPS_DIR}/nghttp3/lib"
fi

# 3. Build ngtcp2
NGTCP2_DIR="${SRC_DEPS}/ngtcp2"
if [ ! -f "${DEPS_DIR}/ngtcp2/lib/libngtcp2.a" ] && [ ! -f "${DEPS_DIR}/ngtcp2/lib64/libngtcp2.a" ]; then
    echo "--> [3/4] Building ngtcp2..."
    mkdir -p "${NGTCP2_DIR}"
    tar -xf "${DL_DIR}/ngtcp2-1.11.0.tar.xz" --strip-components=1 -C "${NGTCP2_DIR}"

    mkdir -p "${NGTCP2_DIR}/build"
    pushd "${NGTCP2_DIR}/build" > /dev/null
    PKG_CONFIG_PATH="${QUICTLS_LIBDIR}/pkgconfig:${NGHTTP3_LIBDIR}/pkgconfig" \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="${DEPS_DIR}/ngtcp2" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_C_COMPILER="${CC}" \
        -DCMAKE_AR="$(which "${AR}" || echo "${AR}")" \
        -DCMAKE_RANLIB="$(which "${RANLIB}" || echo "${RANLIB}")" \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -DENABLE_LIB_ONLY=ON \
        -DENABLE_STATIC_LIB=ON \
        -DENABLE_SHARED_LIB=OFF \
        -DENABLE_OPENSSL=ON \
        -DOPENSSL_ROOT_DIR="${DEPS_DIR}/quictls" \
        -DOPENSSL_INCLUDE_DIR="${DEPS_DIR}/quictls/include" \
        -DOPENSSL_CRYPTO_LIBRARY="${QUICTLS_LIBDIR}/libcrypto.a" \
        -DOPENSSL_SSL_LIBRARY="${QUICTLS_LIBDIR}/libssl.a" \
        -DCMAKE_BUILD_TYPE=Release
    cmake --build . -j"${NPROC}"
    DESTDIR="" cmake --install .
    popd > /dev/null
    echo "--> ngtcp2 installed to ${DEPS_DIR}/ngtcp2"
else
    echo "--> [3/4] ngtcp2 already built, skipping."
fi

if [ -d "${DEPS_DIR}/ngtcp2/lib64" ]; then
    NGTCP2_LIBDIR="${DEPS_DIR}/ngtcp2/lib64"
else
    NGTCP2_LIBDIR="${DEPS_DIR}/ngtcp2/lib"
fi

# Consolidate all .pc files in one location so pkg-config finds them all
COMBINED_PKGCONFIG="${DEPS_DIR}/pkgconfig"
mkdir -p "${COMBINED_PKGCONFIG}"
find "${DEPS_DIR}" -name "*.pc" -exec cp -v {} "${COMBINED_PKGCONFIG}/" \;
# Also copy into quictls pkgconfig directory because curl configure points PKG_CONFIG_LIBDIR there
cp -v "${COMBINED_PKGCONFIG}"/*.pc "${QUICTLS_LIBDIR}/pkgconfig/"

# 4. Build curl
echo "--> [4/4] Building curl with HTTP/3..."
CURL_SRC="${WORK_DIR}/curl"
mkdir -p "${CURL_SRC}"

CURL_TARBALL="$(find "${DL_DIR}" -name "curl-*.tar.xz" | head -n1)"
tar -xf "${CURL_TARBALL}" --strip-components=1 -C "${CURL_SRC}"

pushd "${CURL_SRC}" > /dev/null

export PKG_CONFIG_SYSROOT_DIR=""
export PKG_CONFIG_PATH="${COMBINED_PKGCONFIG}:${QUICTLS_LIBDIR}/pkgconfig:${NGHTTP3_LIBDIR}/pkgconfig:${NGTCP2_LIBDIR}/pkgconfig"
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"

echo "Available pkg-config files in ${COMBINED_PKGCONFIG}:"
ls -la "${COMBINED_PKGCONFIG}"

./configure \
    --host="${HOST}" \
    --prefix="${PREFIX}" \
    --disable-shared \
    --enable-static \
    --with-openssl="${DEPS_DIR}/quictls" \
    --with-ngtcp2="${DEPS_DIR}/ngtcp2" \
    --with-nghttp3="${DEPS_DIR}/nghttp3" \
    --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
    --with-ca-path=/etc/ssl/certs \
    --enable-http \
    --enable-ipv6 \
    --enable-pthreads \
    --enable-websockets \
    --without-zlib \
    --disable-ldap \
    --disable-ldaps \
    --disable-rtsp \
    --disable-dict \
    --disable-telnet \
    --disable-tftp \
    --disable-pop3 \
    --disable-imap \
    --disable-smb \
    --disable-smtp \
    --disable-gopher \
    --disable-manual \
    --without-brotli \
    --without-zstd \
    --without-libidn2 \
    --without-libpsl \
    --without-librtmp \
    --without-libssh2 \
    --without-libssh \
    CC="${CC}" \
    CFLAGS="${CFLAGS} -O2 -I${DEPS_DIR}/quictls/include -I${DEPS_DIR}/nghttp3/include -I${DEPS_DIR}/ngtcp2/include" \
    LDFLAGS="-L${QUICTLS_LIBDIR} -L${NGHTTP3_LIBDIR} -L${NGTCP2_LIBDIR} ${LDFLAGS} -static-libgcc" \
    LIBS="-lssl -lcrypto -lpthread -ldl" \
    OPENSSL_CFLAGS="-I${DEPS_DIR}/quictls/include" \
    OPENSSL_LIBS="-L${QUICTLS_LIBDIR} -lssl -lcrypto -ldl -lpthread" \
    NGHTTP3_CFLAGS="-I${DEPS_DIR}/nghttp3/include" \
    NGHTTP3_LIBS="-L${NGHTTP3_LIBDIR} -lnghttp3" \
    NGTCP2_CFLAGS="-I${DEPS_DIR}/ngtcp2/include" \
    NGTCP2_LIBS="-L${NGTCP2_LIBDIR} -lngtcp2 -lngtcp2_crypto_quictls"

make -j"${NPROC}"
make install DESTDIR="${DESTDIR}"
popd > /dev/null

# Strip final executable
if [ -n "${STRIP:-}" ] && [ -f "${DESTDIR}${PREFIX}/bin/curl" ]; then
    echo "--> Stripping curl binary..."
    "${STRIP}" "${DESTDIR}${PREFIX}/bin/curl"
fi

echo "=================================================="
echo "== Build finished successfully!                =="
echo "=================================================="
ls -lh "${DESTDIR}${PREFIX}/bin/curl"
