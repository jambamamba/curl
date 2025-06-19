#!/bin/bash -xe
set -xe

source share/pins.txt
source share/scripts/helper-functions.sh

function skip(){
    local target="x86"
    local builddir=""
    parseArgs $@
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

function build() {
    local clean=""
    local target="x86"
    local builddir=""
    local cmake_toolchain_file=""
    parseArgs $@
    
    local script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    export ZLIB_LIBRARY=${script_dir}
    export ZLIB_INCLUDE_DIR=${script_dir}

    local srcdir="$(pwd)"
    local cmake_modules_path="${srcdir}/share/cmake-modules"
    pushd "${builddir}"
    if [ "$target" == "mingw" ]; then
        source "${srcdir}/share/toolchains/x86_64-w64-mingw32.sh"
        cmake \
            -DCMAKE_INSTALL_BINDIR=$(pwd) \
            -DCMAKE_INSTALL_LIBDIR=$(pwd) \
            -DCMAKE_MODULE_PATH="${cmake_modules_path}" \
            -DCMAKE_PREFIX_PATH="${cmake_modules_path}" \
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
            -DMINGW=1 \
            -DTARGET=${target} \
            -DCMAKE_TOOLCHAIN_FILE="${srcdir}/curl-options.cmake" \
            -G "Ninja" ..
    elif [ "$target" == "arm" ]; then
        source "${SDK_DIR}/environment-setup-cortexa72-oe-linux"
        cmake \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_MODULE_PATH="${cmake_modules_path}" \
            -DCMAKE_PREFIX_PATH="${cmake_modules_path}" \
            -DCMAKE_TOOLCHAIN_FILE="${srcdir}/curl-options.cmake" \
            -DTARGET=${target} \
            -G "Ninja" ..
    elif [ "$target" == "x86" ]; then
		export STRIP="$(which strip)"
        cmake \
            -DCMAKE_BUILD_TYPE=RelWithDebugInfo \
            -DCMAKE_MODULE_PATH="/usr/local/cmake" \
            -DCMAKE_PREFIX_PATH="/usr/local/cmake" \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_TOOLCHAIN_FILE="${srcdir}/curl-options.cmake" \
            -DTARGET=${target} \
            -G "Ninja" ..
    fi
    ninja
    sudo ninja install #package
    rsync -uav lib/libcurl* .
    popd
}

function installDependencies() {
    local target="x86"
    local depsdir=".deps/${target}"
    local artifacts_url="/downloads"
    parseArgs $@

    if [[ "${installdeps}" == "false" || "${clean}" == "true" ]]; then
        return
    fi

    local libs=(zlib libssh2) #openssl
    for library in "${libs[@]}"; do
        local pin="${library}_pin"
#        echo "${!pin}" #gets the value of variable where the variable name is "${library}_pin"
        local artifacts_file="${library}-${!pin}-${target}.tar.xz"
        mkdir -p /tmp/${library}
        rm -fr /tmp/${library}/*
        pushd /tmp/${library}
        tar xf /downloads/${artifacts_file}
        # cd "${library}-${!pin}-${target}"
        sudo rsync -uav * ${depsdir}/
        popd
        rm -fr "/tmp/${library}"
        # installLib $@ library="${library}" artifacts_file="${artifacts_file}" artifacts_url="${artifacts_url}" depsdir=${depsdir}
    done
}

function main() {
    local target="x86"
    parseArgs $@

    local builddir="${target}-build"
    if [ "$clean" == "true" ]; then
        rm -fr "${builddir}"
    fi
    mkdir -p "${builddir}"

    skip $@ library="curl"
    installDependencies $@ depsdir="/usr/local" 
    build $@ builddir="${builddir}"
    package target="$target" dst="/downloads"

    # # package $@ library="curl" builddir="${builddir}"
    # local library="curl"
    # local builddir="/tmp/${library}/${target}-build"
    # copyBuildFilesToInstalls $@ builddir="${builddir}"
    #     local installsdir="${builddir}/installs"
    #     mv ${installsdir}/include/include ${installsdir}/real_include
    #     rm -fr ${installsdir}/include
    #     mv ${installsdir}/real_include ${installsdir}/include 
    # compressInstalls $@ builddir="${builddir}" library="${library}"

}

time main $@
