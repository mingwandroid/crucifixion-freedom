#!/bin/bash
#
# Copyright (C) 2012 The Android Open Source Project
# Copyright (C) 2012 Ray Donnelly <mingw.android at gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Wrapper script to rebuild the host Python binaries from sources.
#

# platform/prebuilts/gcc/linux-x86/host/i686-linux-glibc2.7-4.6
# git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/i686-linux-glibc2.7-4.6
# platform/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.7-4.6
# git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.7-4.6

# linux32 ./crucifixion-freedom.sh --python-version=2.7.5 --systems=linux-x86_64,linux-x86
# rm -rf /tmp2/cr-build; PATH=$HOME/mingw64/x86_64-w64-mingw32/bin:"${PATH}" linux32 ./crucifixion-freedom.sh --python-version=3.3.0 --systems=linux-x86_64,windows-x86,windows-x86_64
# rm -rf /tmp2/cr-build; PATH=$HOME/mingw64/x86_64-w64-mingw32/bin:"${PATH}" linux32 ./crucifixion-freedom.sh --python-version=2.7.3,3.3.0 --systems=linux-x86_64,linux-x86,windows-x86,windows-x86_64
# rm -rf /tmp2/cr-build; PATH=$HOME/mingw64/x86_64-w64-mingw32/bin:$HOME/darwin-cross/apple-osx/bin:"${PATH}" linux32 ./crucifixion-freedom.sh --python-version=2.7.5 --systems=linux-x86_64,linux-x86,windows-x86,windows-x86_64,darwin-x86,darwin-x86_64
# rm -rf /tmp2/cr-build; PATH=$HOME/darwin-cross/apple-osx/bin:"${PATH}" linux32 ./crucifixion-freedom.sh --python-version=2.7.5 --systems=linux-x86_64,darwin-x86

# rm -rf /tmp2/cr-build; git clean -dxf; export PATH=/c/msys32/mingw32/bin:/c/msys64/mingw64/bin:"${PATH}"; ./crucifixion-freedom.sh --python-version=2.7.5,3.3.0 --systems=windows-x86,windows-x86_64 --compiler-vendors=gcc
# rm -rf /tmp2/cr-build; git clean -dxf; export PATH=/c/msys32/mingw32/bin:/c/msys64/mingw64/bin:"${PATH}"; ./crucifixion-freedom.sh --python-version=2.7.5,3.3.0,3.3.3 --systems=windows-x86,windows-x86_64 --compiler-vendors=gcc
# rm -rf /tmp2/cr-build; git clean -dxf; ./crucifixion-freedom.sh --python-version=2.7.5,3.3.0 --systems=linux-x86,darwin-x86,darwin-x86_64 --compiler-vendors=clang

# PATH=$HOME/mingw64/x86_64-w64-mingw32/bin:"${PATH}" ./crucifixion-freedom.sh --python-version=3.3.3 --systems=linux-x86_64,windows-x86_64

# rm -rf /tmp2/cr-build; git clean -dxf;  export PATH=$HOME/mingw64-i686/mingw32/bin:$HOME/mingw64-x86_64/mingw64/bin:"${PATH}"; ./crucifixion-freedom.sh --python-version=3.3.3 --systems=windows-x86,windows-x86_64 --compiler-vendors=gcc
# rm -rf /tmp2/cr-build; git clean -dxf;  export PATH=$HOME/mingw64-i686/mingw32/bin:$HOME/mingw64-x86_64/mingw64/bin:"${PATH}"; ./crucifixion-freedom.sh --python-version=3.3.3 --systems=windows-x86,windows-x86_64 --compiler-vendors=gcc --no-strip

# rm -rf /tmp2/cr-build; PATH=$HOME/mingw64/x86_64-w64-mingw32/bin:"${PATH}" ./crucifixion-freedom.sh --python-version=3.3.3 --systems=linux-x86_64,windows-x86_64

# For some reason, the install prefix without '/lib' appended makes it into the compiler.library_dirs. I think this happens at the configure stage.
# Due to:
# ('LDFLAGS', '-R', self.compiler.runtime_library_dirs),
# ('LDFLAGS', '-L', self.compiler.library_dirs),
# ('CPPFLAGS', '-I', self.compiler.include_dirs)):
# in setup.py
# ...0505-add-build-sysroot-config-option.patch is looking a bit like something I shouldn't bother with (and thus the --with-build-sysroot= stuff.
# one thing that I must be careful about is making sure that /usr/lib is *never* added to the search paths as finding the wrong arch for a lib
# is fatal, so if the first found version of e.g. libreadline.a is the wrong arch, it doesn't check the next one, it just fails to build the module.
# and 0505- contains stuff for this (/usr is used only if no --with-build-sysroot= are specified). Actually, I prefer my method to parsing CFLAGS
# etc as that stuff is hardwired for GCC-like compilers.

ANDROID_NDK_ROOT=$(cd $PWD && pwd)
NDK=$PWD

ROOT=$PWD

download ()
{
    local _DEST="$1"; shift
    local _SRC="$1"; shift

    if [ ! -d "$_DEST" ]; then
        mkdir -p "$_DEST"
    fi

    if [ -f "$_SRC" ]; then
        cp "$_SRC" "$_DEST"
    else
        (cd $_DEST; curl -S -L -O $_SRC)
    fi
}


# We need a newer MSYS expr.exe and we need it early.
#  I compiled one from coreutils-8.17.
# If you used scripts/windows/BootstrapMinGW64.vbs to create your mingw-w64
#  environment then that will have copied this expr.exe into the bin folder
#  already, but in-case you didn't...
if [ "$OSTYPE" = "msys" ] ; then
    EXPR_RESULT=`expr -- "--test=<value>" : '--[^=]*=\(<.*>\)'`
    if [ ! "$EXPR_RESULT" = "<value>" ] ; then
        echo "Downloading more modern MSYS expr"
        if [ ! -f $PWD/expr.exe ] ; then
            curl -S -L -O http://mingw-and-ndk.googlecode.com/files/expr.exe
        fi
        export PATH="$(pwd -W)":"${PATH}"
    fi
fi

NDK_BUILDTOOLS_PATH="$(dirname $0)/scripts/tools"
. "$NDK_BUILDTOOLS_PATH/prebuilt-common.sh"
. "$NDK_BUILDTOOLS_PATH/common-build-host-funcs.sh"

# PYTHON_VERSION=2.7.3,3.3.0
PYTHON_VERSION=2.7.5

register_var_option "--python-version=<versions>" PYTHON_VERSION "Select Python version(s)."

DARWIN_SYSROOT="$HOME/MacOSX10.7.sdk"
register_var_option "--darwin-sdk=<path>" DARWIN_SYSROOT "Select Darwin SDK path."

PYTHON_BUILD_DIR=/tmp2/cr-build
register_var_option "--build-dir=<path>" PYTHON_BUILD_DIR "Select temp build directory."

TOOLCHAINS=$(pwd_shell $HOME)
register_var_option "--toolchains=<path>" TOOLCHAINS "Select toolchain root directory."

DATESUFFIX=$(date +%y%m%d)
PYTHON_RELEASE_DIR=$PWD/release-$DATESUFFIX
register_var_option "--package-dir=<path>" PYTHON_RELEASE_DIR "Select packaging directory."

PDCURSES_RL=no
register_var_option "--with-pdcurses-rl=<path>" PDCURSES_RL "[Windows] Build PDCurses and readline"

TCLTK=no
register_var_option "--with-tcltk=<path>" TCLTK "Build static tcltk (for Idle)"

COMPILER_VENDORS=gcc
register_var_option "--compiler-vendors=<gcc,clang>" COMPILER_VENDORS "Comma separated list of compilers to build with"

PROGRAM_DESCRIPTION="\
This program sets up and uses a compilation environment to cross compile Python
2.7.3 and/or 3.3.0. It calls scripts/tools/build-host-python.sh to do all of
the hard work.

If you want to use this on Windows, you need to have a good mingw-w64
environment with MSYS installed. To make this, you can run:
scripts/windows/BootstrapMinGW64.vbs

By default, the script rebuilds Python for your host system [$HOST_TAG],
but you can use --systems=<tag1>,<tag2>,.. to ask binaries that can run on
several distinct systems. Each <tag> value in the list can be one of the
following:

   linux-x86
   linux-x86_64
   windows
   windows-x86 (equivalent to 'windows')
   windows-x86_64
   darwin-x86
   darwin-x86_64

For example, here's how to rebuild Python 2.7.3 and 3.3.0 on Linux
for six different systems:

  $PROGNAME --build-dir=/path/to/toolchain/src \\ \n \
    --python-version=2.7.3,3.3.0 \\ \n \
    --darwin-sdk=\"$DARWIN_SYSROOT\" \\ \n \
    --systems=linux-x86,linux-x86_64,windows,windows-x86_64,darwin-x86,darwin-x86_64"

bh_register_options

extract_parameters "$@"

if [ ! -d $ROOT/toolchain-tarballs ]; then
    mkdir $ROOT/toolchain-tarballs
fi

# These are useful if you want to hack on these patches (to regenerate *-re-configure-d.patch)

# For Python-2.7.3 -> this should really be done on MSYS!
# if [ ! -d $HOME/autoconf-2.67 ]; then
#     (cd $ROOT/toolchain-tarballs; curl -S -L -O http://ftp.gnu.org/gnu/autoconf/autoconf-2.67.tar.bz2)
#     (cd /tmp; tar -xjf $ROOT/toolchain-tarballs/autoconf-2.67.tar.bz2; cd autoconf-2.67; M4=$(which m4) ./configure --prefix=$HOME/autoconf-2.67; make; make install)
# fi
# export PATH=$HOME/autoconf-2.67/bin:"${PATH}"

# For Python-3.3.x
if [ ! -d $HOME/autoconf-2.69 ]; then
    (cd $ROOT/toolchain-tarballs; curl -S -L -O http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz)
    (cd /tmp; tar -xvf $ROOT/toolchain-tarballs/autoconf-2.69.tar.gz; cd autoconf-2.69; M4=$(which m4) ./configure --prefix=$HOME/autoconf-2.69; make; make install)
fi
# export PATH=$HOME/autoconf-2.69/bin:"${PATH}"

if [ ! -z "$PYTHONHOME" ]; then
    echo "ERROR: PYTHONHOME variable set to $PYTHONHOME, refusing to build."
    exit 1
fi

if [ ! -z "$PYTHONPATH" ]; then
    echo "ERROR: PYTHONPATH variable set to $PYTHONPATH, refusing to build."
    exit 1
fi

bh_set_build_tag $HOST_TAG

# Need to write a shell function that takes the host tag and the build tag and returns some properties:
# 1. The toolchain's tarball (for downloading)
# 2. The bin folder prefix (xz for adding to the PATH)
# A minor detail about this is that we consider all compilations to require a toolchain, even if it's
#  native to native. This is for a few reasons:
#   1. To prevent broken toolchains (e.g. Apple's llvmgcc) breaking the build
#   2. To ensure compatability with older releases of the OS (e.g. Linux glibc2.7)

setup_toolchain_env_for_compilation ()
{
    local _BUILD_TAG=$1
    local _HOST_TAG=$2

    case $_BUILD_TAG in
        linux*)
        ;;
        windows*)
        ;;
        darwin*)
        ;;
        *)
            panic "Can't handle build machine $_BUILD_TAG"
        ;;
    esac
}

uncompress ()
{
    local _ARCHIVE=$1
    case $_ARCHIVE in
      *.7z)
        7za x $_ARCHIVE
      ;;
      *.tar.bz2)
        tar -xjf $_ARCHIVE
      ;;
      *.tar.xz)
        tar -xJf $_ARCHIVE
      ;;
    esac
}


# Makes a directory symlink on Windows.
# $1 is the link name (created), in MSYS land.
# $2 is the target name (existing), in MSYS land.
# I would use lns by Nokia but it's bugged, so lots of path
# transformation and cmd.exe's mklink builtin are used.
# I tend to need this for two reasons:
# 1. Paths with spaces. (programs in e.g. "Program Files"
#     are not compatible with gnumake).
# 2. Asymetric MSYS path transformations (sometimes xformed,
#     sometimes not leading to all sorts of failure).
win_mklink ()
{
    local _LINK="$1"
    local _TARG="$2"
    local _LINK_PARENT_WIN=$(dirname "$_LINK")
    _LINK_PARENT_WIN=($(cd "$_LINK_PARENT_WIN"; pwd -W))
    _LINK_PARENT_WIN=${_LINK_PARENT_WIN//\//\\}
    cmd.exe /c "if not exist $_LINK_PARENT_WIN mkdir $_LINK_PARENT_WIN"

    local _TARG_PARENT_WIN=$(dirname "$_TARG")
    _TARG_PARENT_WIN=("$(cd "$_TARG_PARENT_WIN"; pwd -W)")
    _TARG_PARENT_WIN=${_TARG_PARENT_WIN//\//\\}
    cmd.exe /c "if not exist $_TARG_PARENT_WIN mkdir $_TARG_PARENT_WIN"

    local _TARG_WIN="$_TARG_PARENT_WIN"\\$(basename "$_TARG")
    local _LINK_WIN="$_LINK_PARENT_WIN"\\$(basename "$_LINK")

    cmd.exe /c "if not exist $_LINK_WIN mklink /D \"$_LINK_WIN\" \"$_TARG_WIN\""
}

if [ $BH_BUILD_OS = windows ]; then
    DARWIN_CROSS_FILENAME=http://mingw-and-ndk.googlecode.com/files/multiarch-darwin11-cctools127.2-gcc42-5666.3-llvmgcc42-2336.1-Windows-120614.7z
    MINGW_GCC_EXC_VAR64=sjlj
    MINGW_GCC_EXC_THREADS=win32
    MINGW_GCC_SRC_VER=4.8.2
    MINGW_GCC_EXC_VAR32=dwarf
    MINGW_SF_URL="http://sourceforge.net/projects/mingw-w64/files"
      MINGW_GCC_VER32=i686-${MINGW_GCC_SRC_VER}-release-${MINGW_GCC_EXC_THREADS}-${MINGW_GCC_EXC_VAR32}-rt_v3-rev0
    MINGW_GCC_VER64=x86_64-${MINGW_GCC_SRC_VER}-release-${MINGW_GCC_EXC_THREADS}-${MINGW_GCC_EXC_VAR64}-rt_v3-rev0
    MINGW_CROSS_FILENAME="${MINGW_SF_URL}/Toolchains%20targetting%20Win32/Personal%20Builds/mingw-builds/${MINGW_GCC_SRC_VER}/threads-${MINGW_GCC_EXC_THREADS}/${MINGW_GCC_EXC_VAR32}/${MINGW_GCC_VER32}.7z"
    MINGW_CROSS_FILENAME_64="${MINGW_SF_URL}/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/${MINGW_GCC_SRC_VER}/threads-${MINGW_GCC_EXC_THREADS}/${MINGW_GCC_EXC_VAR64}/${MINGW_GCC_VER64}.7z"
    DEFAULT_SYSTEMS=windows-x86,windows-x86_64
elif [ $BH_BUILD_OS = darwin ]; then
    DARWIN_CROSS_FILENAME=http://mingw-and-ndk.googlecode.com/files/multiarch-darwin11-cctools127.2-gcc42-5666.3-llvmgcc42-2336.1-Darwin-120615.7z
    MINGW_CROSS_FILENAME=http://heanet.dl.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win32/Automated%20Builds/mingw-w32-bin_i686-darwin_20120528.tar.bz2
    DEFAULT_SYSTEMS=darwin-x86,darwin-x86_64
elif [ $BH_BUILD_OS = linux ]; then
    DARWIN_CROSS_FILENAME=http://mingw-and-ndk.googlecode.com/files/multiarch-darwin11-cctools127.2-gcc42-5666.3-llvmgcc42-2336.1-Linux-120724.tar.xz
# .. testing for crosstool-ng based toolchain builds.
    DARWIN_CROSS_FILENAME=$HOME/Dropbox/crosstool-ng-work/i686-apple-darwin11-linux-x86.tar.xz
    MINGW_CROSS_FILENAME=http://mingw-and-ndk.googlecode.com/files/i686-w64-mingw32-linux-i686-glibc2.7.tar.bz2
    MINGW_CROSS_FILENAME_64=http://mingw-and-ndk.googlecode.com/files/i686-w64-mingw32-linux-i686-glibc2.7.tar.bz2
    # The next two are git repositories.
    LINUX32_CROSS_TOOLCHAIN=https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/i686-linux-glibc2.7-4.6
    LINUX64_CROSS_TOOLCHAIN=https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.7-4.6
    DEFAULT_SYSTEMS=darwin-x86,darwin-x86_64,windows-x86,windows-x86_64,linux-x86_64,linux-x86
fi

if [ "$BH_HOST_SYSTEMS" = "" ] ; then
    BH_HOST_SYSTEMS=$DEFAULT_SYSTEMS
fi

# Install and set paths to all needed compilers.
SYSTEMSLIST=$(commas_to_spaces $BH_HOST_SYSTEMS)

if [ ! $(bh_list_contains "linux-x86" $SYSTEMSLIST) = no -o ! $(bh_list_contains "linux-x86_64" $SYSTEMSLIST) = no ] ; then
    # I need Linux targeting cross compilers for Darwin and Windows...
    for LINUX_CROSS_TOOLCHAIN in $LINUX32_CROSS_TOOLCHAIN $LINUX64_CROSS_TOOLCHAIN; do
        if [ ! -d $TOOLCHAINS/google-prebuilt ]; then
            mkdir -p $TOOLCHAINS/google-prebuilt
        fi
        if [ ! -d $TOOLCHAINS/google-prebuilt/$(basename $LINUX_CROSS_TOOLCHAIN) ]; then
            (cd $TOOLCHAINS/google-prebuilt; git clone $LINUX_CROSS_TOOLCHAIN $(basename $LINUX_CROSS_TOOLCHAIN))
        fi
        if [ ! -d prebuilts/gcc/linux-x86/host ]; then
            mkdir -p prebuilts/gcc/linux-x86/host
        fi
        if [ ! -d prebuilts/gcc/linux-x86/host/$(basename $LINUX_CROSS_TOOLCHAIN) ]; then
            ln -s $TOOLCHAINS/google-prebuilt/$(basename $LINUX_CROSS_TOOLCHAIN) prebuilts/gcc/linux-x86/host/$(basename $LINUX_CROSS_TOOLCHAIN)
        fi
        export PATH=$TOOLCHAINS/google-prebuilt/$(basename $LINUX_CROSS_TOOLCHAIN)/bin:"${PATH}"
    done
fi

if [ ! $(bh_list_contains "windows-x86" $SYSTEMSLIST) = no ]; then
    if [ ! -d $TOOLCHAINS/mingw64-i686 ]; then
        download $ROOT/toolchain-tarballs $MINGW_CROSS_FILENAME
        (mkdir -p $TOOLCHAINS/mingw64-i686; cd $TOOLCHAINS/mingw64-i686; $(uncompress $ROOT/toolchain-tarballs/$(basename $MINGW_CROSS_FILENAME)))
    fi
    if [ $BH_BUILD_OS = windows ]; then
        export PATH=$TOOLCHAINS/mingw64-i686/mingw32/bin:"${PATH}"
    else
        export PATH=$TOOLCHAINS/mingw64-i686/i686-w64-mingw32/bin:"${PATH}"
    fi
fi

if [ ! $(bh_list_contains "windows-x86_64" $SYSTEMSLIST) = no ] ; then
    if [ ! -d $TOOLCHAINS/mingw64-x86_64 ]; then
        download $ROOT/toolchain-tarballs $MINGW_CROSS_FILENAME_64
        (mkdir -p $TOOLCHAINS/mingw64-x86_64; cd $TOOLCHAINS/mingw64-x86_64; $(uncompress $ROOT/toolchain-tarballs/$(basename $MINGW_CROSS_FILENAME_64)))
    fi
    if [ $BH_BUILD_OS = windows ]; then
        export PATH=$TOOLCHAINS/mingw64-x86_64/mingw64/bin:"${PATH}"
    else
        export PATH=$TOOLCHAINS/mingw64-x86_64/i686-w64-mingw32/bin:"${PATH}"
    fi
fi

if [ ! $(bh_list_contains "darwin-x86" $SYSTEMSLIST) = no -o ! $(bh_list_contains "darwin-x86_64" $SYSTEMSLIST) = no ] ; then
    if [ ! -d $TOOLCHAINS/darwin-cross/apple-osx/bin ]; then
        download $ROOT/toolchain-tarballs $DARWIN_CROSS_FILENAME
        (
         if [ -f $DARWIN_CROSS_FILENAME ]; then
             EXTRACTROOT=$TOOLCHAINS/darwin-cross/apple-osx
         else
             EXTRACTROOT=$TOOLCHAINS/darwin-cross
         fi
         mkdir -p $EXTRACTROOT
         cd $EXTRACTROOT
         uncompress $ROOT/toolchain-tarballs/$(basename $DARWIN_CROSS_FILENAME)
        )
    fi
    export PATH=$TOOLCHAINS/darwin-cross/apple-osx/bin:"${PATH}"
    if [ -f $TOOLCHAINS/darwin-cross/apple-osx/bin/i686-apple-darwin11-clang -o -f $TOOLCHAINS/darwin-cross/apple-osx/bin/i686-apple-darwin11-gcc ]; then
        export DARWIN_TOOLCHAIN="i686-apple-darwin11"
    elif [ -f $TOOLCHAINS/darwin-cross/apple-osx/bin/x86_64-apple-darwin10-clang -o -f $TOOLCHAINS/darwin-cross/apple-osx/bin/x86_64-apple-darwin10-gcc ]; then
        export DARWIN_TOOLCHAIN="x86_64-apple-darwin10"
    fi
    echo DARWIN_TOOLCHAIN = $DARWIN_TOOLCHAIN
fi

if [ ! $(bh_list_contains "darwin-x86" $SYSTEMSLIST) = no -o ! $(bh_list_contains "darwin-x86_64" $SYSTEMSLIST) = no -o $BH_BUILD_OS = darwin ] ; then
    export DARWIN_SYSROOT=$DARWIN_SYSROOT
fi

# Without this, running setup.py will fail as it'll be using un-msys-transformed
# versions of the paths.
if [ $BH_BUILD_OS = windows ]; then
    if [ ! -d $PYTHON_BUILD_DIR ] ; then
        mkdir -p $PYTHON_BUILD_DIR
    fi

#    PYTHON_BUILD_DIR_WIN_LINK_PARENT=$(dirname $PYTHON_BUILD_DIR)
#    PYTHON_BUILD_DIR_WIN_LINK_PARENT=${PYTHON_BUILD_DIR_WIN_LINK_PARENT//\//\\}
#    cmd.exe /c "if not exist $PYTHON_BUILD_DIR_WIN_LINK_PARENT mkdir $PYTHON_BUILD_DIR_WIN_LINK_PARENT"
#    PYTHON_BUILD_DIR_WIN_LINK=${PYTHON_BUILD_DIR//\//\\}
#    PYTHON_BUILD_DIR_REAL=($(cd $PYTHON_BUILD_DIR; pwd -W))
#    PYTHON_BUILD_DIR_WIN_REAL=${PYTHON_BUILD_DIR_REAL//\//\\}
#    cmd.exe /c "if not exist $PYTHON_BUILD_DIR_WIN_LINK mklink /D $PYTHON_BUILD_DIR_WIN_LINK $PYTHON_BUILD_DIR_WIN_REAL"

    # Turn MSYS path e.g. /a/msys/path into a literal Windows path, e.g. C:\a\msys\path
    PYTHON_BUILD_DIR_WIN_LINK=${PYTHON_BUILD_DIR//\//\\}
    win_mklink "$PYTHON_BUILD_DIR_WIN_LINK" "$PYTHON_BUILD_DIR"
fi

$ROOT/scripts/tools/build-host-python.sh \
    --systems=$BH_HOST_SYSTEMS \
    --build-dir=$PYTHON_BUILD_DIR \
    --package-dir=$PYTHON_RELEASE_DIR \
    --python-version=$PYTHON_VERSION \
    --compiler-vendors=$COMPILER_VENDORS

exit 0

# You can ignore everything after this line. It's a scratch area I use for regenerating
# patches!

PATH=$HOME/mingw64/x86_64-w64-mingw32/bin:"${PATH}" ./crucifixion-freedom.sh --python-version=2.7.5 --systems=linux-x86_64,windows-x86,windows-x86_64
PATH=$HOME/darwin-cross/apple-osx/bin:"${PATH}" ./crucifixion-freedom.sh --python-version=2.7.5 --systems=linux-x86_64,darwin-x86

PATH=$HOME/mingw64/x86_64-w64-mingw32/bin:$HOME/darwin-cross/apple-osx/bin:"${PATH}" ./crucifixion-freedom.sh --python-version=2.7.5 --systems=linux-x86_64,linux-x86,darwin-x86,darwin-x86_64,windows-x86,windows-x86_64


ROOT=$PWD
PYVER=2.7.3
rm -rf a b Python-${PYVER}
tar -xjf /c/Users/nonesush/Dropbox/Python/SourceTarballs/${PYVER}/Python-$PYVER.tar.bz2
PATCHESDIR=$ROOT/patches/python/$PYVER
pushd Python-$PYVER
patch -p1 < $PATCHESDIR/0000-CROSS.patch
patch -p1 < $PATCHESDIR/0005-MINGW.patch
patch -p1 < $PATCHESDIR/0006-mingw-removal-of-libffi-patch.patch
patch -p1 < $PATCHESDIR/0007-mingw-system-libffi.patch
patch -p1 < $PATCHESDIR/0010-mingw-use-posix-getpath.patch
patch -p1 < $PATCHESDIR/0015-cross-darwin.patch
patch -p1 < $PATCHESDIR/0020-mingw-sysconfig-like-posix.patch
patch -p1 < $PATCHESDIR/0025-mingw-pdcurses_ISPAD.patch
patch -p1 < $PATCHESDIR/0030-mingw-static-tcltk.patch
patch -p1 < $PATCHESDIR/0035-mingw-x86_64-size_t-format-specifier-pid_t.patch
patch -p1 < $PATCHESDIR/0040-python-disable-dbm.patch
patch -p1 < $PATCHESDIR/0045-disable-grammar-dependency-on-pgen-executable.patch
patch -p1 < $PATCHESDIR/0050-add-python-config-sh.patch
patch -p1 < $PATCHESDIR/0055-mingw-nt-threads-vs-pthreads.patch
patch -p1 < $PATCHESDIR/0060-cross-dont-add-multiarch-paths-if.patch
patch -p1 < $PATCHESDIR/0065-mingw-reorder-bininstall-ln-symlink-creation.patch
patch -p1 < $PATCHESDIR/0070-mingw-use-backslashes-in-compileall-py.patch
patch -p1 < $PATCHESDIR/0075-mingw-distutils-MSYS-convert_path-fix-and-root-hack.patch
patch -p1 < $PATCHESDIR/0100-upgrade-internal-libffi-to-3.0.11.patch
patch -p1 < $PATCHESDIR/0105-mingw-MSYS-no-usr-lib-or-usr-include.patch
popd
mv Python-${PYVER} a
cp -rf a b
pushd b
~/autoconf-2.67/bin/autoconf; ~/autoconf-2.67/bin/autoheader;
rm pyconfig.h.in~
rm -rf autom4te.cache
popd
diff -urN a b > $PATCHESDIR/9999-re-configure-d.patch



ROOT=$PWD
PYVER=2.7.5
rm -rf a b Python-${PYVER}
tar -xjf $HOME/Dropbox/Python/SourceTarballs/${PYVER}/Python-$PYVER.tar.bz2
PATCHESDIR=$ROOT/patches/python/$PYVER
pushd Python-$PYVER
patch -p1 < $PATCHESDIR/0005-MINGW.patch
patch -p1 < $PATCHESDIR/0006-mingw-removal-of-libffi-patch.patch
patch -p1 < $PATCHESDIR/0007-mingw-system-libffi.patch
patch -p1 < $PATCHESDIR/0010-mingw-osdefs-DELIM.patch
patch -p1 < $PATCHESDIR/0015-mingw-use-posix-getpath.patch
patch -p1 < $PATCHESDIR/0020-mingw-w64-test-for-REPARSE_DATA_BUFFER.patch
patch -p1 < $PATCHESDIR/0025-mingw-regen-with-stddef-instead.patch
patch -p1 < $PATCHESDIR/0030-mingw-add-libraries-for-_msi.patch
patch -p1 < $PATCHESDIR/0035-MSYS-add-MSYSVPATH-AC_ARG.patch
patch -p1 < $PATCHESDIR/0040-mingw-cygwinccompiler-use-CC-envvars-and-ld-from-print-prog-name.patch
patch -p1 < $PATCHESDIR/0045-cross-darwin.patch
patch -p1 < $PATCHESDIR/0050-mingw-sysconfig-like-posix.patch
patch -p1 < $PATCHESDIR/0055-mingw-pdcurses_ISPAD.patch
patch -p1 < $PATCHESDIR/0060-mingw-static-tcltk.patch
patch -p1 < $PATCHESDIR/0065-mingw-x86_64-size_t-format-specifier-pid_t.patch
patch -p1 < $PATCHESDIR/0070-python-disable-dbm.patch
patch -p1 < $PATCHESDIR/0075-add-python-config-sh.patch
patch -p1 < $PATCHESDIR/0080-mingw-nt-threads-vs-pthreads.patch
patch -p1 < $PATCHESDIR/0085-cross-dont-add-multiarch-paths-if.patch
patch -p1 < $PATCHESDIR/0090-mingw-reorder-bininstall-ln-symlink-creation.patch
patch -p1 < $PATCHESDIR/0095-mingw-use-backslashes-in-compileall-py.patch
patch -p1 < $PATCHESDIR/0100-mingw-distutils-MSYS-convert_path-fix-and-root-hack.patch
patch -p1 < $PATCHESDIR/0105-mingw-MSYS-no-usr-lib-or-usr-include.patch
patch -p1 < $PATCHESDIR/0110-mingw-_PyNode_SizeOf-decl-fix.patch
patch -p1 < $PATCHESDIR/0115-mingw-cross-includes-lower-case.patch
patch -p1 < $PATCHESDIR/0500-mingw-install-LDLIBRARY-to-LIBPL-dir.patch
patch -p1 < $PATCHESDIR/0505-add-build-sysroot-config-option.patch
patch -p1 < $PATCHESDIR/0510-cross-PYTHON_FOR_BUILD-gteq-275-and-fullpath-it.patch
patch -p1 < $PATCHESDIR/0515-mingw-add-GetModuleFileName-path-to-PATH.patch
patch -p1 < $PATCHESDIR/0520-Add-interp-Python-DESTSHARED-to-PYTHONPATH-b4-pybuilddir-txt-dir.patch
patch -p1 < $PATCHESDIR/0525-msys-monkeypatch-os-system-via-sh-exe.patch
popd
mv Python-${PYVER} a
cp -rf a b
pushd b
autoconf; autoheader;
rm pyconfig.h.in~
rm -rf autom4te.cache
popd
diff -urN a b > $PATCHESDIR/9999-re-configure-d.patch

tidy_patches ()
{
    PYVER=$1; shift
    FINAL=$1; shift
    PATCHES="$1"; shift
    ROOT=$PWD
    if [ "$FINAL" != "yes" -a "$FINAL" != "no" ]; then
        echo "tidy_patches arg2 (FINAL) should be yes or no"
        echo "depending on whether you are correcting a mid"
        echo "patch-set patch or re-generating them all and"
        echo "thus require a new 9999-re-configure-d.patch."
        return 1
    fi
    PATCHESDIR=$ROOT/patches/python/$PYVER
    PATCHESDIRNEW=$ROOT/patches/python/$PYVER.new
    # For when not feeling confident about this!
    PATCHESDIRNEW=$ROOT/patches/python/$PYVER.new
    mkdir -p $PATCHESDIRNEW
    tar -xjf $HOME/Dropbox/Python/SourceTarballs/${PYVER}/Python-$PYVER.tar.bz2
    rm -rf ${PATCHESDIR}.backup
    cp -rf ${PATCHESDIR} ${PATCHESDIR}.backup
    if [ -d a ]; then
        rm -rf a
    fi
    mv Python-$PYVER a
    LAST=${PATCHES##* }
    for PATCH in $PATCHES; do
        echo "Patching with: $PATCH"
        if [ -d b ]; then
            rm -rf b
        fi
        cp -rf a b
        pushd b
        patch -p1 < ${PATCHESDIR}/$PATCH
        if [ -n "$(find . -name "*.rej")" ]; then
            popd
            echo "ERROR: Failed to apply $PATCH"
            return 1
        fi
        find . -name "*.orig" -exec rm {} \;
        popd
        # If regenerating a mid-patch and this is
        # that last patch, then bail out at this
        # point so the user can make changes. Give
        # them some instructions about this.
        if [ "$FINAL" = "no" -a "$PATCH" = "$LAST" ]; then
            echo ""
            echo "Please make your fixes in b/ and when"
            echo "done, execute:"
            echo "cd $PWD; diff -urN a b > ${PATCHESDIRNEW}/$PATCH"
            echo "to regenerate this patch"
            echo ""
            return 0
        fi
        diff -urN a b > ${PATCHESDIRNEW}/$PATCH
        rm -rf a
        cp -rf b a
    done
    rm -rf a
    cp -rf b a
    pushd b
    autoconf; autoheader;
    rm pyconfig.h.in~
    rm -rf autom4te.cache
    popd
    diff -urN a b > ${PATCHESDIRNEW}/9999-re-configure-d.patch
    return 0
}

PATCHES_275=\
"0005-MINGW.patch 0006-mingw-removal-of-libffi-patch.patch 0007-mingw-system-libffi.patch \
0010-mingw-osdefs-DELIM.patch 0015-mingw-use-posix-getpath.patch 0020-mingw-w64-test-for-REPARSE_DATA_BUFFER.patch \
0025-mingw-regen-with-stddef-instead.patch 0030-mingw-add-libraries-for-_msi.patch 0035-MSYS-add-MSYSVPATH-AC_ARG.patch \
0040-mingw-cygwinccompiler-use-CC-envvars-and-ld-from-print-prog-name.patch 0045-cross-darwin.patch \
0050-mingw-sysconfig-like-posix.patch 0055-mingw-pdcurses_ISPAD.patch 0060-mingw-static-tcltk.patch \
0065-mingw-x86_64-size_t-format-specifier-pid_t.patch 0070-python-disable-dbm.patch 0075-add-python-config-sh.patch \
0080-mingw-nt-threads-vs-pthreads.patch 0085-cross-dont-add-multiarch-paths-if.patch \
0090-mingw-reorder-bininstall-ln-symlink-creation.patch 0095-mingw-use-backslashes-in-compileall-py.patch \
0100-mingw-distutils-MSYS-convert_path-fix-and-root-hack.patch 0105-mingw-MSYS-no-usr-lib-or-usr-include.patch \
0110-mingw-_PyNode_SizeOf-decl-fix.patch 0115-mingw-cross-includes-lower-case.patch \
0500-mingw-install-LDLIBRARY-to-LIBPL-dir.patch 0505-add-build-sysroot-config-option.patch \
0510-cross-PYTHON_FOR_BUILD-gteq-275-and-fullpath-it.patch 0515-mingw-add-GetModuleFileName-path-to-PATH.patch \
0520-Add-interp-Python-DESTSHARED-to-PYTHONPATH-b4-pybuilddir-txt-dir.patch \
0525-msys-monkeypatch-os-system-via-sh-exe.patch"
tidy_patches "2.7.5" yes "$PATCHES_275"

PATCHES_273=\
"0000-CROSS.patch 0005-MINGW.patch 0006-mingw-removal-of-libffi-patch.patch \
0007-mingw-system-libffi.patch 0010-mingw-use-posix-getpath.patch 0015-cross-darwin.patch \
0020-mingw-sysconfig-like-posix.patch 0025-mingw-pdcurses_ISPAD.patch \
0030-mingw-static-tcltk.patch 0035-mingw-x86_64-size_t-format-specifier-pid_t.patch \
0040-python-disable-dbm.patch 0045-disable-grammar-dependency-on-pgen-executable.patch \
0050-add-python-config-sh.patch 0055-mingw-nt-threads-vs-pthreads.patch \
0060-cross-dont-add-multiarch-paths-if.patch 0065-mingw-reorder-bininstall-ln-symlink-creation.patch \
0070-mingw-use-backslashes-in-compileall-py.patch 0075-mingw-distutils-MSYS-convert_path-fix-and-root-hack.patch \
0100-upgrade-internal-libffi-to-3.0.11.patch 0105-mingw-MSYS-no-usr-lib-or-usr-include.patch \
9999-re-configure-d.patch"
tidy_patches "2.7.3" yes "$PATCHES_273"

PATCHES_330=\
"0000-add-python-config-sh.patch 0005-cross-fixes.patch \
0010-cross-darwin-feature.patch 0030-py3k-20121004-MINGW.patch \
0031-py3k-20121004-MINGW-removal-of-pthread-patch.patch 0032-py3k-20121004-MINGW-ntthreads.patch \
0033-py3k-mingw-ntthreads-vs-pthreads.patch 0034-py3k-20121004-MINGW-removal-of-libffi-patch.patch \
0035-mingw-system-libffi.patch 0045-mingw-use-posix-getpath.patch \
0050-mingw-sysconfig-like-posix.patch 0055-mingw-_winapi_as_builtin_for_Popen_in_cygwinccompiler.patch \
0060-mingw-x86_64-size_t-format-specifier-pid_t.patch 0065-cross-dont-add-multiarch-paths-if-cross-compiling.patch \
0070-mingw-use-backslashes-in-compileall-py.patch 0075-msys-convert_path-fix-and-root-hack.patch \
0080-mingw-hack-around-double-copy-scripts-issue.patch 0085-allow-static-tcltk.patch \
0090-CROSS-avoid-ncursesw-include-path-hack.patch 0091-CROSS-properly-detect-WINDOW-_flags-for-different-nc.patch \
0092-mingw-pdcurses_ISPAD.patch 0095-no-xxmodule-for-PYDEBUG.patch 0100-grammar-fixes.patch \
0105-builddir-fixes.patch 0110-msys-monkeypatch-os-system-via-sh-exe.patch 0115-msys-replace-slashes-used-in-io-redirection.patch"
tidy_patches "3.3.0" yes "$PATCHES_330"

PATCHES_333="\
0460-py3k-20121004-MINGW.patch \
0470-py3k-20121004-MINGW-removal-of-pthread-patch.patch \
0480-py3k-20121004-MINGW-ntthreads.patch \
0490-add-python-config-sh.patch \
0500-cross-darwin-feature.patch \
0510-py3k-mingw-ntthreads-vs-pthreads.patch \
0520-py3k-20121004-MINGW-removal-of-libffi-patch.patch \
0530-mingw-system-libffi.patch \
0540-mingw-semicolon-DELIM.patch \
0550-mingw-regen-use-stddef_h.patch \
0560-mingw-use-posix-getpath.patch \
0570-mingw-add-BUILDIN_WIN32_MODULEs-time-msvcrt.patch \
0580-mingw32-test-REPARSE_DATA_BUFFER.patch \
0590-mingw-INSTALL_SHARED-LDLIBRARY-LIBPL.patch \
0600-msys-mingw-prefer-unix-sep-if-MSYSTEM.patch \
0610-msys-cygwin-semi-native-build-sysconfig.patch \
0620-mingw-sysconfig-like-posix.patch \
0630-mingw-_winapi_as_builtin_for_Popen_in_cygwinccompiler.patch \
0640-mingw-x86_64-size_t-format-specifier-pid_t.patch \
0650-cross-dont-add-multiarch-paths-if-cross-compiling.patch \
0660-mingw-use-backslashes-in-compileall-py.patch \
0670-msys-convert_path-fix-and-root-hack.patch \
0680-mingw-hack-around-double-copy-scripts-issue.patch \
0690-allow-static-tcltk.patch \
0700-CROSS-avoid-ncursesw-include-path-hack.patch \
0710-CROSS-properly-detect-WINDOW-_flags-for-different-nc.patch \
0720-mingw-pdcurses_ISPAD.patch \
0730-no-xxmodule-for-PYDEBUG.patch \
0740-grammar-fixes.patch \
0750-builddir-fixes.patch \
0760-msys-monkeypatch-os-system-via-sh-exe.patch \
0770-msys-replace-slashes-used-in-io-redirection.patch \
0780-Use-MACHDEP-for-SHLIB_SUFFIX.patch \
0790-mingw-add-_exec_prefix-for-tcltk-dlls.patch"

tidy_patches "3.3.3" yes "$PATCHES_333"


ROOT=$PWD
PYVER=3.3.0
rm -rf a-${PYVER} b-${PYVER} Python-${PYVER}
tar -xjf ~/Dropbox/Python/SourceTarballs/Python-$PYVER.tar.bz2
PATCHESDIR=$ROOT/patches/python/$PYVER
pushd Python-$PYVER
patch -p1 < $PATCHESDIR/0000-add-python-config-sh.patch
patch -p1 < $PATCHESDIR/0005-cross-fixes.patch
patch -p1 < $PATCHESDIR/0010-cross-darwin-feature.patch
patch -p1 < $PATCHESDIR/0030-py3k-20121004-MINGW.patch
patch -p1 < $PATCHESDIR/0031-py3k-20121004-MINGW-removal-of-pthread-patch.patch
patch -p1 < $PATCHESDIR/0032-py3k-20121004-MINGW-ntthreads.patch
patch -p1 < $PATCHESDIR/0033-py3k-mingw-ntthreads-vs-pthreads.patch
patch -p1 < $PATCHESDIR/0034-py3k-20121004-MINGW-removal-of-libffi-patch.patch
patch -p1 < $PATCHESDIR/0035-mingw-system-libffi.patch
patch -p1 < $PATCHESDIR/0045-mingw-use-posix-getpath.patch
patch -p1 < $PATCHESDIR/0050-mingw-sysconfig-like-posix.patch
patch -p1 < $PATCHESDIR/0055-mingw-_winapi_as_builtin_for_Popen_in_cygwinccompiler.patch
patch -p1 < $PATCHESDIR/0060-mingw-x86_64-size_t-format-specifier-pid_t.patch
patch -p1 < $PATCHESDIR/0065-cross-dont-add-multiarch-paths-if-cross-compiling.patch
patch -p1 < $PATCHESDIR/0070-mingw-use-backslashes-in-compileall-py.patch
patch -p1 < $PATCHESDIR/0075-msys-convert_path-fix-and-root-hack.patch
patch -p1 < $PATCHESDIR/0080-mingw-hack-around-double-copy-scripts-issue.patch
patch -p1 < $PATCHESDIR/0085-allow-static-tcltk.patch
patch -p1 < $PATCHESDIR/0090-CROSS-avoid-ncursesw-include-path-hack.patch
patch -p1 < $PATCHESDIR/0091-CROSS-properly-detect-WINDOW-_flags-for-different-nc.patch
patch -p1 < $PATCHESDIR/0092-mingw-pdcurses_ISPAD.patch
patch -p1 < $PATCHESDIR/0095-no-xxmodule-for-PYDEBUG.patch
patch -p1 < $PATCHESDIR/0100-grammar-fixes.patch
patch -p1 < $PATCHESDIR/0105-builddir-fixes.patch
patch -p1 < $PATCHESDIR/0110-msys-monkeypatch-os-system-via-sh-exe.patch
patch -p1 < $PATCHESDIR/0115-msys-replace-slashes-used-in-io-redirection.patch
# I didn't apply the following patches (they're in 3.3.0.alex and
# would need renumbering and regenerating...):
# patch -p1 < $PATCHESDIR/0013-CROSS-fix-typo-in-thread-AC_CACHE_VAL.patch
# patch -p1 < $PATCHESDIR/0014-CROSS-restore-importlib-header-to-source-directory-a.patch
# patch -p1 < $PATCHESDIR/0016-CROSS-initialise-include-and-library-paths.patch
# patch -p1 < $PATCHESDIR/0018-CROSS-use-_PYTHON_PROJECT_BASE-in-distutils-sysconfi.patch
# patch -p1 < $PATCHESDIR/0019-CROSS-pass-all-top-configure-arguments-to-libffi-con.patch
# patch -p1 < $PATCHESDIR/0020-CROSS-warn-only-if-readelf-is-not-in-host-triplet-fo.patch
# patch -p1 < $PATCHESDIR/0021-CROSS-append-gcc-library-search-paths-instead-to-pre.patch
# patch -p1 < $PATCHESDIR/0024-CROSS-use-build-directory-as-root-for-regression-tes.patch
# patch -p1 < $PATCHESDIR/0025-CROSS-test-tools-has-to-depend-only-from-location-of.patch
popd
mv Python-$PYVER a-${PYVER}
cp -rf a-${PYVER} b-${PYVER}
pushd b-${PYVER}



ROOT=$PWD
PYVER=3.4.x
rm -rf a-${PYVER} b-${PYVER} Python-${PYVER}
tar -xjf ~/Dropbox/Python/SourceTarballs/3.4./Python-$PYVER.tar.bz2
PATCHESDIR=$ROOT/patches/python/$PYVER
pushd Python-$PYVER
patch -p1 < $PATCHESDIR/0000-add-python-config-sh.patch
patch -p1 < $PATCHESDIR/0005-cross-fixes.patch
patch -p1 < $PATCHESDIR/0010-cross-darwin-feature.patch
popd
mv Python-$PYVER a-${PYVER}
cp -rf a-${PYVER} b-${PYVER}
pushd b-${PYVER}
~/autoconf-2.69/bin/autoconf; ~/autoconf-2.69/bin/autoheader;
rm pyconfig.h.in~
rm -rf autom4te.cache
popd
diff -urN a b > $PATCHESDIR/9999-re-configure-d.patch



ROOT=$PWD
PYVER=3.3.0b1
rm -rf a-${PYVER} b-${PYVER} Python-${PYVER}
tar -xjf ~/Dropbox/Python/SourceTarballs/3.3.0/Python-$PYVER.tar.bz2
PATCHESDIR=$ROOT/patches/python/$PYVER
pushd Python-$PYVER
patch -p1 < $PATCHESDIR/0000-CROSS.patch
patch -p1 < $PATCHESDIR/0005-MINGW.patch
patch -p1 < $PATCHESDIR/0010-MINGW-fixes-use-posix-getpath.patch
patch -p1 < $PATCHESDIR/0015-DARWIN-CROSS.patch
patch -p1 < $PATCHESDIR/0020-MINGW-FIXES-sysconfig-like-posix.patch
patch -p1 < $PATCHESDIR/0025-MINGW-pdcurses_ISPAD.patch
patch -p1 < $PATCHESDIR/0030-MINGW-static-tcltk.patch
patch -p1 < $PATCHESDIR/0035-MINGW-x86_64-size_t-format-specifier-pid_t.patch
patch -p1 < $PATCHESDIR/0040-add-python-config-sh.patch
patch -p1 < $PATCHESDIR/0045-force-libffi-configure-srcdir.patch
patch -p1 < $PATCHESDIR/0050-MINGW-define-wcstok-as-wcstok_s.patch
patch -p1 < $PATCHESDIR/0055-mingw-_winapi_as_builtin_for_Popen_in_cygwinccompiler.patch
patch -p1 < $PATCHESDIR/0075-msys-convert_path-fix-and-root-hack.patch
patch -p1 < $PATCHESDIR/0080-py3k-mingw-ntthreads-vs-pthreads.patch
patch -p1 < $PATCHESDIR/9999-re-configure-d.patch
popd
mv Python-$PYVER a-${PYVER}
cp -rf a-${PYVER} b-${PYVER}
pushd b-${PYVER}


# Alexey's having a segmentation fault with tcl/tk support in mingw-builds:
# Get msys64 user version (i.e. not developer version)
git clone https://github.com/Alexpux/mingw-builds.git --branch develop
cd mingw-builds
nano library/subtargets.sh [uncomment tcl tk]
./build --mode=python-2.7.5 --jobs=3 --buildroot=/tmp --arch=x86_64
# It'll fail ..

# To reproduce it:
pushd /tmp/python-x86_64/build/Python-2.7.5
DISTUTILS_DEBUG=1 PATH=~/mingw-builds/toolchains/mingw64/bin:/tmp/python-x86_64/libs/bin:"${PATH}" CC='x86_64-w64-mingw32-gcc' LDSHARED='x86_64-w64-mingw32-gcc -shared -Wl,--enable-auto-image-base -pipe -L/tmp/python-x86_64/libs/lib -L/tmp/prerequisites/x86_64-zlib/lib -L/tmp/prerequisites/x86_64-w64-mingw32-static/lib -L/tmp/python-x86_64/python-2.7.5-x86_64/opt/lib -L/x86_64-zlib/lib -LC:/msys64/tmp/python-x86_64/python-2.7.5-x86_64/opt/lib -LC:/msys64/tmp/python-x86_64/libs/lib' OPT='-DNDEBUG ' ./python.exe -E ../../../src/Python-2.7.5/setup.py --verbose build


# 3.3.3 doesn't pick up the right MACHDEP.
export PATH=/tmp2/cr-build/toolchain-wrappers-gcc:/tmp2/cr-build/install/windows-x86_64/python-3.3.0-gcc/bin:"${PATH}"

# Linux cross:
/tmp2/cr-build/toolchain-wrappers-gcc/x86_64-w64-mingw32-gcc \
-DNDEBUG -g -fwrapv -O3 -Wall -Wstrict-prototypes \
-I/tmp2/cr-build/install/windows-x86_64/python-3.3.3-gcc_static_libs/include -I/tmp2/cr-build/install/windows-x86_64/python-3.3.3-gcc_static_libs/include/ncursesw \
-D__USE_MINGW_ANSI_STDIO=1 \   ### This is extra/redundant on Linux
-I/tmp2/cr-build/install/windows-x86_64/python-3.3.3-gcc/include \
-D__USE_MINGW_ANSI_STDIO=1 \
-I. \
-I/tmp2/cr-build/install/windows-x86_64/python-3.3.3-gcc/include \
-I/tmp2/cr-build/tmp/src/Python-3.3.3/PC \
-I/tmp2/cr-build/tmp/src/Python-3.3.3/Python \
-I/tmp2/cr-build/tmp/src/Python-3.3.3/Include \
-I/tmp2/cr-build/build-python-windows-x86_64-3.3.3 \
-c /tmp2/cr-build/tmp/src/Python-3.3.3/Modules/_struct.c -o build/temp.mingw-3.3/tmp2/cr-build/tmp/src/Python-3.3.3/Modules/_struct.o

# Windows native:
C:/msys64/bin/sh.exe /tmp2/cr-build/toolchain-wrappers-gcc/x86_64-w64-mingw32-gcc \
-DNDEBUG -g         -O3 -Wall -Wstrict-prototypes \
-I/tmp2/cr-build/install/windows-x86_64/python-3.3.3-gcc_static_libs/include \
-I/tmp2/cr-build/install/windows-x86_64/python-3.3.3-gcc_static_libs/include/ncursesw \
-I/tmp2/cr-build/install/windows-x86_64/python-3.3.3-gcc/include \
-D__USE_MINGW_ANSI_STDIO=1 \
-I. \
-IC:\tmp2\cr-build\tmp\src\Python-3.3.3\Include \
-IC:\msys64\tmp2\cr-build\build-python-windows-x86_64-3.3.3 \
-c _struct.c -o build\temp.win32-3.3\_struct.o


# You can edit:
C:\msys64\tmp2\cr-build\build-python-windows-x86_64-3.3.3\Makefile (modify e.g. srcdir=		/tmp2/cr-build/tmp/src/Python-3.3.3-what-a-terrible-failure)
# Then:
pushd /tmp2/cr-build/build-python-windows-x86_64-3.3.3
# Then:
./python.exe -E -S -m sysconfig --generate-posix-vars
# Then:
 ./python.exe -c 'import sysconfig ; print(sysconfig.get_config_var("srcdir")); '
# Outputs:
C:\tmp2\cr-build\tmp\src\Python-3.3.3-what-a-terrible-failure
# So what's fixing the paths?

# That'd be C:\msys64\tmp2\cr-build\tmp\src\Python-3.3.3\Lib\sysconfig.py
def get_config_vars(*args):

..
        # Always convert srcdir to an absolute path
        srcdir = _CONFIG_VARS.get('srcdir', _PROJECT_BASE)
        if posix_build:
            if _PYTHON_BUILD:
                # If srcdir is a relative path (typically '.' or '..')
                # then it should be interpreted relative to the directory
                # containing Makefile.
                base = os.path.dirname(get_makefile_filename())
                srcdir = os.path.join(base, srcdir)
            else:
                # srcdir is not meaningful since the installation is
                # spread about the filesystem.  We choose the
                # directory containing the Makefile since we know it
                # exists.
                srcdir = os.path.dirname(get_makefile_filename())
        _CONFIG_VARS['srcdir'] = _safe_realpath(srcdir)

.. what on earth is this all about? it does not check if srcdir is relative before appending it onto dir containing Makefile ..
.. so that when it is used in:

C:\msys64\tmp2\cr-build\tmp\src\Python-3.3.3\setup.py

# Fix up the autodetected modules, prefixing all the source files
# with Modules/.
srcdir = sysconfig.get_config_var('srcdir')
if not srcdir:
    # Maybe running on Windows but not using posix build?
    raise ValueError("No source directory; cannot proceed.")
srcdir = os.path.abspath(srcdir)
moddirlist = [os.path.join(srcdir, 'Modules')]

.. moddirlist is in the builddir (where Makefile was) and not the srcdir. I do not understand why this would work on Linux either though
.. unless srcdir in the Makefile was relative all the way along?

# This patch needs splitting:
C:\Users\ukrdonnell\crucifixion-freedom\patches\python\3.3.3\0045-mingw-use-posix-getpath.patch

# Into:
0041-mingw-semicolon-DELIM.patch
0042-mingw-regen-use-stddef_h.patch
0043-mingw-use-posix-getpath.patch
0044-mingw-add-BUILDIN_WIN32_MODULEs-time-msvcrt.patch
0045-mingw32-test-REPARSE_DATA_BUFFER.patch
# And then follow by:
0046-mingw-INSTALL_SHARED-LDLIBRARY-LIBPL.patch
0047-msys-mingw-prefer-unix-sep-if-MSYSTEM.patch
0048-msys-cygwin-semi-native-build-sysconfig.patch

# Test building C modules.
pushd ~/Dropbox/Python
# Simple test with Python in --prefix location:
/tmp2/cr-build/install/windows-x86_64/python-3.3.3-gcc/bin/python3.3.exe test-build-module.py build
# More complicated test against a moved version of Python.
cp -rf /tmp2/cr-build/install/windows-x86_64/python-3.3.3-gcc /tmp/py-moved
/tmp/py-moved/bin/python3.3.exe test-build-module.py build
popd

# Seems we have python-3.3/config added as a libdir in
# C:\msys64\tmp2\cr-build\install\windows-x86_64\python-3.3.3-gcc\lib\python3.3\distutils\command\build_ext.py :
# building third party extensions
# self.library_dirs.append(os.path.join(sys.prefix, "lib",
#                                       "python" + get_python_version(),
#                                       "config"))
# but not config-3.3 like we need ..
