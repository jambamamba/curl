#!/bin/bash -xe
set -xe

source share/scripts/helper-functions.sh

function skip(){
    local target="x86"
    parseArgs $@
    local builddir="${target}-build"
    local SHA="$(sudo git config --global --add safe.directory .;sudo git rev-parse --verify --short HEAD)"
    local package="${library}-${SHA}-${target}.tar.xz"

    if [ "$target" == "mingw" ] && \
        [ -f "${builddir}/lib/libcurl.dll" ] && \
        [ -f "${builddir}/${package}" ]; then 
        return 1
    elif [ "$target" == "x86" ] && \
        [ -f "${builddir}/lib/libcurl.so.4.8.0" ] && \
        [ -f "${builddir}/${package}" ]; then 
        return 1
    elif [ "$target" == "arm" ] && \
        [ -f "${builddir}/lib/libcurl.so.4.8.0" ] && \
        [ -f "${builddir}/${package}" ]; then 
        return 1
    fi
    return 0
}

function build(){
    local clean=""
    local target="x86"
    local cmake_toolchain_file=""
    parseArgs $@
    
    local builddir="${target}-build"
    mkdir -p "${builddir}"
    # local postfix="-1.1.1t"

    if [ "$clean" == "true" ]; then
        rm -fr "${builddir}/*"
    fi

    local script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    export ZLIB_LIBRARY=${script_dir}
    export ZLIB_INCLUDE_DIR=${script_dir}
    pushd "${builddir}"

    if [ "$target" == "mingw" ]; then
        source "../share/toolchains/x86_64-w64-mingw32.sh"
        cmake \
            -DCMAKE_INSTALL_BINDIR=$(pwd) \
            -DCMAKE_INSTALL_LIBDIR=$(pwd) \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_SKIP_RPATH=TRUE \
            -DCMAKE_SKIP_INSTALL_RPATH=TRUE \
            -DWIN32=TRUE \
            -DMINGW64=${MINGW64} \
            -DWITH_GCRYPT=OFF \
            -DWITH_MBEDTLS=OFF \
            -DHAVE_STRTOULL=1 \
            -DHAVE_COMPILER__FUNCTION__=1 \
            -DHAVE_GETADDRINFO=1 \
            -DENABLE_CUSTOM_COMPILER_FLAGS=OFF \
            -DBUILD_CLAR=OFF \
            -DTHREADSAFE=ON \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER=$CC \
            -DCMAKE_RC_COMPILER=$RESCOMP \
            -DDLLTOOL=$DLLTOOL \
            -DCMAKE_FIND_ROOT_PATH=/usr/x86_64-w64-mingw32 \
            -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
            -DCMAKE_INSTALL_PREFIX=../install-win \
            -G "Ninja" ..
    elif [ "$target" == "arm" ]; then
        source "${SDK_DIR}/environment-setup-aarch64-fslc-linux"
        cmake \
            -DBUILD_SHARED_LIBS=ON \
            -G "Ninja" ..
    elif [ "$target" == "x86" ]; then
		export STRIP="$(which strip)"
        cmake \
            -DBUILD_SHARED_LIBS=ON \
            -G "Ninja" ..
    fi
    ninja
    rsync -uav lib/libcurl* .
    popd
}

function main(){
   skip $@ library="curl"
   build $@
   package $@ library="curl"
}

time main $@