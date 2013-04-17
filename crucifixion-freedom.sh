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

ANDROID_NDK_ROOT=$(cd $PWD && pwd)
NDK=$PWD

ROOT=$PWD

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
        export PATH="$(pwd -W)":$PATH
    fi
fi

NDK_BUILDTOOLS_PATH="$(dirname $0)/scripts/tools"
. "$NDK_BUILDTOOLS_PATH/prebuilt-common.sh"
. "$NDK_BUILDTOOLS_PATH/common-build-host-funcs.sh"

PYTHON_VERSION=2.7.3,3.3.0

register_var_option "--python-version=<versions>" PYTHON_VERSION "Select Python version(s)."

DARWIN_SYSROOT="/usr/nec/host_compiler_tools/darwin/MacOSX10.7.sdk"
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
# export PATH=$HOME/autoconf-2.67/bin:$PATH

# For Python-3.3.0
if [ ! -d $HOME/autoconf-2.69 ]; then
    (cd $ROOT/toolchain-tarballs; curl -S -L -O http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz)
    (cd /tmp; tar -xvf $ROOT/toolchain-tarballs/autoconf-2.69.tar.gz; cd autoconf-2.69; M4=$(which m4) ./configure --prefix=$HOME/autoconf-2.69; make; make install)
fi
# export PATH=$HOME/autoconf-2.69/bin:$PATH

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
    MINGW_CROSS_FILENAME=http://heanet.dl.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win32/Personal%20Builds/rubenvb/release/i686-w64-mingw32-gcc-4.7.0-release-win32_rubenvb.7z
    MINGW_CROSS_FILENAME_64=http://kent.dl.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win64/Automated%20Builds/mingw-w64-bin_i686-mingw_20111220.zip
    DEFAULT_SYSTEMS=windows-x86,windows-x86_64
elif [ $BH_BUILD_OS = darwin ]; then
    DARWIN_CROSS_FILENAME=http://mingw-and-ndk.googlecode.com/files/multiarch-darwin11-cctools127.2-gcc42-5666.3-llvmgcc42-2336.1-Darwin-120615.7z
    MINGW_CROSS_FILENAME=http://heanet.dl.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win32/Automated%20Builds/mingw-w32-bin_i686-darwin_20120528.tar.bz2
    DEFAULT_SYSTEMS=darwin-x86,darwin-x86_64
elif [ $BH_BUILD_OS = linux ]; then
    DARWIN_CROSS_FILENAME=http://mingw-and-ndk.googlecode.com/files/multiarch-darwin11-cctools127.2-gcc42-5666.3-llvmgcc42-2336.1-Linux-120724.tar.xz
    MINGW_CROSS_FILENAME=http://mingw-and-ndk.googlecode.com/files/i686-w64-mingw32-linux-i686-glibc2.7.tar.bz2
    LINUX_CROSS_TOOLCHAIN=http://mingw-and-ndk.googlecode.com/files/i686-linux-glibc2.7-4.4.3.tar.bz2
    DEFAULT_SYSTEMS=darwin-x86,darwin-x86_64,windows-x86,windows-x86_64,linux-x86_64,linux-x86
fi

if [ "$BH_HOST_SYSTEMS" = "" ] ; then
    BH_HOST_SYSTEMS=$DEFAULT_SYSTEMS
fi

# Install and set paths to all needed compilers.
SYSTEMSLIST=$(commas_to_spaces $BH_HOST_SYSTEMS)

if [ ! $(bh_list_contains "linux-x86" $SYSTEMSLIST) = no -o ! $(bh_list_contains "linux-x86_64" $SYSTEMSLIST) = no ] ; then
    # I need Linux targeting cross compilers for Darwin and Windows...
    if [ ! -z "$LINUX_CROSS_TOOLCHAIN" ] ; then
        if [ ! -d $TOOLCHAINS/google-prebuilt ]; then
            if [ ! -f $ROOT/toolchain-tarballs/$(basename $LINUX_CROSS_TOOLCHAIN) ]; then
                (cd $ROOT/toolchain-tarballs; curl -S -L -O $LINUX_CROSS_TOOLCHAIN)
            fi
            (mkdir -p $TOOLCHAINS/google-prebuilt; cd $TOOLCHAINS/google-prebuilt; tar -xJf $ROOT/toolchain-tarballs/$(basename $LINUX_CROSS_TOOLCHAIN))
        fi
        export PATH=$TOOLCHAINS/google-prebuilt/linux-x86/toolchain/i686-linux-glibc2.7-4.4.3/bin:$PATH
    fi
fi

if [ ! $(bh_list_contains "windows-x86" $SYSTEMSLIST) = no -o ! $(bh_list_contains "windows-x86_64" $SYSTEMSLIST) = no ] ; then
    if [ ! -d $TOOLCHAINS/mingw64 ]; then
        if [ ! -f $ROOT/toolchain-tarballs/$(basename $MINGW_CROSS_FILENAME) ]; then
            (cd $ROOT/toolchain-tarballs; curl -S -L -O $MINGW_CROSS_FILENAME)
        fi
        (mkdir -p $TOOLCHAINS/mingw64; cd $TOOLCHAINS/mingw64; $(uncompress $ROOT/toolchain-tarballs/$(basename $MINGW_CROSS_FILENAME)))
    fi
    export PATH=$TOOLCHAINS/mingw64/i686-w64-mingw32/bin:$PATH
fi

if [ ! $(bh_list_contains "darwin-x86" $SYSTEMSLIST) = no -o ! $(bh_list_contains "darwin-x86_64" $SYSTEMSLIST) = no ] ; then
    if [ ! -d $TOOLCHAINS/darwin-cross/apple-osx ]; then
        if [ ! -f $ROOT/toolchain-tarballs/$(basename $DARWIN_CROSS_FILENAME) ]; then
            (cd $ROOT/toolchain-tarballs; curl -S -L -O $DARWIN_CROSS_FILENAME)
        fi
        (mkdir -p $TOOLCHAINS/darwin-cross; cd $TOOLCHAINS/darwin-cross; $(uncompress $ROOT/toolchain-tarballs/$(basename $DARWIN_CROSS_FILENAME)))
    fi
    export PATH=$TOOLCHAINS/darwin-cross/apple-osx/bin:$PATH
    export DARWIN_TOOLCHAIN="i686-apple-darwin11"
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
    --python-version=$PYTHON_VERSION

exit 0

# You can ignore everything after this line. It's a scratch area I use for regenerating
# patches!



ROOT=$PWD
PYVER=2.7.3
rm -rf a-${PYVER} b-${PYVER} Python-${PYVER}
tar -xjf ~/Dropbox/Python/SourceTarballs/${PYVER}/Python-$PYVER.tar.bz2
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
popd
mv Python-${PYVER} a-${PYVER}
cp -rf a-${PYVER} b-${PYVER}
pushd b-${PYVER}
~/autoconf-2.67/bin/autoconf; ~/autoconf-2.67/bin/autoheader;
rm pyconfig.h.in~
rm -rf autom4te.cache
popd
diff -urN a-${PYVER} b-${PYVER} > $PATCHESDIR/9999-re-configure-d.patch



ROOT=$PWD
PYVER=2.7.4
rm -rf a-${PYVER} b-${PYVER} Python-${PYVER}
tar -xjf ~/Dropbox/Python/SourceTarballs/${PYVER}/Python-$PYVER.tar.bz2
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
patch -p1 < $PATCHESDIR/0050-add-python-config-sh.patch
patch -p1 < $PATCHESDIR/0055-mingw-nt-threads-vs-pthreads.patch
patch -p1 < $PATCHESDIR/0060-cross-dont-add-multiarch-paths-if.patch
patch -p1 < $PATCHESDIR/0065-mingw-reorder-bininstall-ln-symlink-creation.patch
patch -p1 < $PATCHESDIR/0070-mingw-use-backslashes-in-compileall-py.patch
patch -p1 < $PATCHESDIR/0075-mingw-distutils-MSYS-convert_path-fix-and-root-hack.patch
popd
mv Python-${PYVER} a-${PYVER}
cp -rf a-${PYVER} b-${PYVER}
pushd b-${PYVER}
autoconf; autoheader;
rm pyconfig.h.in~
rm -rf autom4te.cache
popd
diff -urN a-${PYVER} b-${PYVER} > $PATCHESDIR/9999-re-configure-d.patch





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
