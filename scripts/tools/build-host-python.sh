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
# Rebuild the host Python binaries from sources.
#

# include common function and variable definitions
NDK_BUILDTOOLS_PATH="$(dirname $0)"
. "$NDK_BUILDTOOLS_PATH/prebuilt-common.sh"
. "$NDK_BUILDTOOLS_PATH/common-build-host-funcs.sh"

PROGRAM_PARAMETERS=""
PROGRAM_DESCRIPTION="\
This program is used to rebuild one or more Python client programs from
sources. To use it, you will need a working set of toolchain sources, like
those downloaded with download-toolchain-sources.sh, then pass the
corresponding directory with the --toolchain-src-dir=<path> option.

By default, the script rebuilds Python for you host system [$HOST_TAG],
but you can use --systems=<tag1>,<tag2>,.. to ask binaries that can run on
several distinct systems. Each <tag> value in the list can be one of the
following:

   linux-x86
   linux-x86_64
   windows-x86
   windows-x86_64
   darwin-x86
   darwin-x86_64

For example, here's how to rebuild Python 2.7.3 on Linux
for six different systems:

  $PROGNAME --build-dir=/path/to/toolchain/src \n \
    --python-version=2.7.3 \n \
    --systems=linux-x86,linux-x86_64,windows,windows-x86_64,darwin-x86,darwin-x86_64"

PYTHON_VERSION=2.7.3
register_var_option "--python-version=<version>" PYTHON_VERSION "Select Python version."

NDK_DIR=$ANDROID_NDK_ROOT
register_var_option "--ndk-dir=<path>" NDK_DIR "Select NDK install directory."

PACKAGE_DIR=
register_var_option "--package-dir=<path>" PACKAGE_DIR "Package prebuilt tarballs into directory."

BUILD_DIR=
register_var_option "--build-dir=<path>" BUILD_DIR "Build Python into directory"

WINTHREADS=nt
# NYI
# register_var_option "--winthreads=<posix|nt>" WINTHREADS "Select Windows threading API."

# Selects PDCurses instead of ncurses and mingweditline instead of readline.
AVOID_GPL=yes

bh_register_options

register_jobs_option

extract_parameters "$@"

if [ -n "$PARAMETERS" ]; then
    panic "This script doesn't take parameters, only options. See --help"
fi

BH_HOST_SYSTEMS=$(commas_to_spaces $BH_HOST_SYSTEMS)

# Python needs to execute itself during its build process, so must build the build
# Python first. It should also be an error if not asked to build for build machine.
BH_HOST_SYSTEMS=$(bh_sort_systems_build_first "$BH_HOST_SYSTEMS")

# Make sure that the the user asked for the build OS's Python to be built.
#  and that the above sort command worked correctly.
if [ ! "$(bh_list_contains $BH_BUILD_TAG $BH_HOST_SYSTEMS)" = "first" ] ; then
    panic "Cross-compiling Python requires building for the build OS, add $BH_BUILD_TAG to --systems=<list>"
fi

if [ ! "$(bh_list_contains darwin-x86 $BH_HOST_SYSTEMS)" = "no" -o ! "$(bh_list_contains darwin-x86_64 $BH_HOST_SYSTEMS)" = "no" ] ; then
    if [ ! -d "$DARWIN_SYSROOT" ]; then
        panic "Darwin SDK path ($DARWIN_SYSROOT) doesn't exist, pass correct location with --darwin-sdk=<path>"
    fi
fi

mingw_threading_cflag ()
{
	local RESULT=
	if [ "$WINTHREADS" = "posix" ] ; then
		RESULT="-mthreads"
	fi
    if [ ! "$RESULT" = "" ] ; then
        if [ $(echo "" | $CC $RESULT -E -) ] ; then
            panic "$CC doesn't support $RESULT"
        fi
    fi
    echo $RESULT
}

mingw_threading_configure_arg ()
{
    local RESULT=
#    if [ "$WINTHREADS" = "posix" ] ; then
#        RESULT="-mthreads"
#    fi
#    if [ ! "$RESULT" = "" ] ; then
#        if [ $(echo "" | $CC $RESULT -E -) ] ; then
#            panic "$CC doesn't support $RESULT"
#        fi
#    fi
#    if [ ! "$RESULT" = "-mthreads" ] ; then
#        echo "--without-threads"
#    fi
    echo ""
}

download_package ()
{
    # Assume the packages are already downloaded under $ARCHIVE_DIR
    local PKG_URL=$1
    local _SRC_DIR=$2
    local PKG_NAME=$(basename $PKG_URL)

    if [ "$_SRC_DIR" = "" ] ; then
        _SRC_DIR=$SRC_DIR
    fi

    dump "Downloading ${PKG_URL}, extracting to ${_SRC_DIR}"

    case $PKG_NAME in
        *.tar.bz2)
            PKG_BASENAME=${PKG_NAME%%.tar.bz2}
            ;;
        *.tar.gz)
            PKG_BASENAME=${PKG_NAME%%.tar.gz}
            ;;
        *)
            panic "Unknown archive type: $PKG_NAME"
    esac

    if [ ! -f "$ARCHIVE_DIR/$PKG_NAME" ]; then
        log "Downloading $PKG_URL..."
        download_file "$PKG_URL" "$ARCHIVE_DIR/$PKG_NAME"
        fail_panic "Can't download '$PKG_URL'"
    fi

    if [ ! -d "$_SRC_DIR/$PKG_BASENAME" ]; then
        log "Uncompressing $PKG_URL into $_SRC_DIR"
        case $PKG_NAME in
            *.tar.bz2)
                run tar xjf $ARCHIVE_DIR/$PKG_NAME -C $_SRC_DIR
                ;;
            *.tar.gz)
                run tar xzf $ARCHIVE_DIR/$PKG_NAME -C $_SRC_DIR
                ;;
            *)
                panic "Unknown archive type: $PKG_NAME"
                ;;
        esac
        fail_panic "Can't uncompress $ARCHIVE_DIR/$PKG_NAME"
    fi
}

prepare_download

if [ -z "$BUILD_DIR" ] ; then
    BUILD_DIR=/tmp/ndk-$USER/buildhost
fi

bh_setup_build_dir $BUILD_DIR

# "$BH_BUILD_MODE" = "debug" is broken currently!?
# PYDEBUG="--with-pydebug"
if [ "$BH_BUILD_MODE" = "debug" ] ; then
   PYDEBUG="--with-pydebug"
   SAVE_TEMPS=" --save-temps "
fi

# Sanity check that we have the right compilers for all hosts
for SYSTEM in $BH_HOST_SYSTEMS; do
    bh_setup_build_for_host $SYSTEM
done

TEMP_DIR=$BUILD_DIR/tmp
# Download and unpack source packages from official sites
ARCHIVE_DIR=$TEMP_DIR/archive
SRC_DIR=$TEMP_DIR/src
STAMP_DIR=$TEMP_DIR/timestamps
BUILD_DIR=$TEMP_DIR/build-$HOST_TAG

mkdir -p $BUILD_DIR

PROGDIR=`dirname $0`
PROGDIR=$(cd $PROGDIR && pwd)

# beta versions get removed from python's official ftp site.
BASEURL=http://www.python.org/ftp/python
# this site keeps them around though.
#BASEURL=http://mirrors.wayround.org/www.python.org/www.python.org/ftp/python
# ..for quicker turn around when I'm developing:
#BASEURL=$HOME/Dropbox/Python/SourceTarballs

for VERSION in $(commas_to_spaces $PYTHON_VERSION); do
    PYTHON_SRCDIR=$SRC_DIR/Python-$VERSION
    if [ ! -d $PYTHON_SRCDIR ] ; then
        mkdir -p $ARCHIVE_DIR
        mkdir -p $SRC_DIR
        VERSION_FOLDER=$(echo ${VERSION} | sed 's/\([0-9\.]*\).*/\1/')
        download_package ${BASEURL}/${VERSION_FOLDER}/Python-${VERSION}.tar.bz2
        PATCHES_DIR="$ANDROID_NDK_ROOT/patches/python/${VERSION}"
        PATCHES=$(find $PATCHES_DIR -name "*.patch" | sort)
        dump "Patching Python-${VERSION} sources"
        for PATCH in $PATCHES; do
            dump "Patching $PATCH"
            (cd $SRC_DIR/Python-$VERSION && run patch -p1 < $PATCH)
        done
    fi
    if [ ! -d "$PYTHON_SRCDIR" ]; then
        panic "Missing source directory: $PYTHON_SRCDIR"
    fi
done


# Return the build install directory of a given Python version
# $1: host system tag
# $2: python version
python_build_install_dir ()
{
    echo "$BH_BUILD_DIR/install/$1/python-$2"
}

# $1: host system tag
# $2: python version
python_ndk_package_name ()
{
    echo "python-$2"
}


# Same as python_build_install_dir, but for the final NDK installation
# directory. Relative to $NDK_DIR.
python_ndk_install_dir ()
{
    echo "prebuilt/$1/python-$2"
}

arch_to_qemu_arch ()
{
    case $1 in
        x86)
            echo i386
            ;;
        *)
            echo $1
            ;;
    esac
}

# For curses and panel modules on Windows.
make_pdcurses ()
{
    local _HOST_TAG=$1
    local _PREFIX=$2
    local _BUILD="--build=$BH_BUILD_CONFIG"
    local _HOST="--host=$BH_HOST_CONFIG"
    local _HOST_SRC_DIR=${SRC_DIR}-${_HOST_TAG}

    mkdir -p $_PREFIX/include
    mkdir -p $_PREFIX/lib
    mkdir -p $_HOST_SRC_DIR

    if [[ ! -f $_PREFIX/lib/libncurses.a ]] ; then
        download_package http://downloads.sourceforge.net/pdcurses/pdcurses/3.4/PDCurses-3.4.tar.gz ${_HOST_SRC_DIR}
        (
        cd ${_HOST_SRC_DIR}/PDCurses-3.4/win32
        sed '90s/-copy/-cp/' mingwin32.mak > mingwin32-fixed.mak
        # AR isn't used in the below!
        make -f mingwin32-fixed.mak WIDE=Y UTF8=Y DLL=N CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB"
        $RANLIB pdcurses.a
        cp pdcurses.a $_PREFIX/lib/libncurses.a
        cp pdcurses.a $_PREFIX/lib/libpanel.a
        sed 's/\#define PDC_BUILD 3401/\#define PDC_BUILD 3401\n#define _ISPAD 0x10/' ../curses.h > ../curses.fixed.h
        sed 's/\#define PDC_BUILD 3401/\#define PDC_BUILD 3401\n#define _ISPAD 0x10/' ../panel.h > ../panel.fixed.h
        cp ../curses.fixed.h $_PREFIX/include/ncurses.h
        cp ../curses.fixed.h $_PREFIX/include/curses.h
        cp ../panel.fixed.h $_PREFIX/include/panel.h
        )
    fi
}

make_ncurses ()
{
    local _HOST_TAG=$1
    local _PREFIX=$2
    local _BUILD="--build=$BH_BUILD_CONFIG"
    local _HOST="--host=$BH_HOST_CONFIG"
    local _HOST_SRC_DIR=${SRC_DIR}-${_HOST_TAG}

    mkdir -p $_PREFIX/include
    mkdir -p $_PREFIX/lib
    mkdir -p $_HOST_SRC_DIR

    if [[ ! -f $_PREFIX/lib/libncursesw.a ]] ; then
        download_package http://ftp.gnu.org/pub/gnu/ncurses/ncurses-5.9.tar.gz ${_HOST_SRC_DIR}
        (
        cd ${_HOST_SRC_DIR}/ncurses-5.9
        ./configure --prefix=$_PREFIX --enable-static --disable-shared --enable-term-driver --enable-sp-funcs --enable-widec CFLAGS="-D__USE_MINGW_ANSI_STDIO=1"
        make -j$NUM_JOBS > ncurses_make.log 2>&1
        make install > ncurses_install.log 2>&1
        )
    fi
}

make_readline ()
{
    local _HOST_TAG=$1
    local _PREFIX=$2
    local _BUILD="--build=$BH_BUILD_CONFIG"
    local _HOST="--host=$BH_HOST_CONFIG"
    local _HOST_SRC_DIR=${SRC_DIR}-${_HOST_TAG}

    mkdir -p $_PREFIX/include
    mkdir -p $_PREFIX/lib
    mkdir -p $_HOST_SRC_DIR

    # should this not be readline/readline.h?
    if [[ ! -f $_PREFIX/include/readline.h ]] ; then
        download_package ftp://ftp.cwru.edu/pub/bash/readline-6.2.tar.gz ${_HOST_SRC_DIR}
        (
        cd ${_HOST_SRC_DIR}/readline-6.2
        ./configure --prefix=$_PREFIX --disable-shared --enable-static $_HOST > rl_config.log 2>&1
        make -j$NUM_JOBS > rl_make.log 2>&1
        make install > rl_install.log 2>&1
        )
    fi
}

# mingweditline is sadly lacking in too many ways to be a drop in replacement for readline or even OSX editline.
make_editline ()
{
    local _HOST_TAG=$1
    local _PREFIX=$2
    local _PREFIXFINAL=$3
    local _BUILD="--build=$BH_BUILD_CONFIG"
    local _HOST="--host=$BH_HOST_CONFIG"
    local _HOST_SRC_DIR=${SRC_DIR}-${_HOST_TAG}

    mkdir -p $_PREFIX/include
    mkdir -p $_PREFIX/lib
    mkdir -p $_HOST_SRC_DIR

    if [[ ! -f $_PREFIX/include/readline/readline.h ]] ; then
       download_package http://garr.dl.sourceforge.net/project/mingweditline/mingweditline-2.07.tar.bz2 ${_HOST_SRC_DIR}
       if [ $_HOST_TAG = windows-x86 ] ; then
           MAKEFILE=Makefile.gcc32
           LIBDIR=../lib32
       elif [ $_HOST_TAG = windows-x86_64 ] ; then
           MAKEFILE=Makefile.gcc64
           LIBDIR=../lib64
       fi
       (
       cd ${_HOST_SRC_DIR}/mingweditline-2.07/src
       make -j$NUM_JOBS -f $MAKEFILE PREFIX= CC=$CC > el_make.log 2>&1
       make install -f $MAKEFILE > el_install.log 2>&1
       cp ${LIBDIR}/libedit.a ${_PREFIX}/lib/libreadline.a
       mkdir -p ${_PREFIX}/include/readline/
       cp ../include/editline/readline.h ${_PREFIX}/include/readline/readline.h
       cp ../include/editline/readline.h ${_PREFIX}/include/readline/history.h
       mkdir -p ${_PREFIXFINAL}
       cp ../COPYING ${_PREFIXFINAL}/COPYING.mingweditline
       )
    fi
}

# Needed for idle.
# See:
# http://objectmix.com/tcl/15449-how-cross-compile-tcl8-4-tk8-4-arm-linux.html
# also see:
# http://www.eyrie.org/~eagle/notes/rpath.html
# "It's becoming more and more common these days to link everything against shared libraries, and in fact many
#  software packages (Tcl and Cyrus SASL come to mind) basically just don't work properly static." - great.
make_tcltk ()
{
    local _HOST_TAG=$1
    local _PREFIX=$2
    local _BUILD=$3
    local _HOST=$4
    mkdir -p $_PREFIX/include
    mkdir -p $_PREFIX/lib

    if [ $_HOST_TAG = windows-x86 -o $_HOST_TAG = windows-x86_64 ] ; then
        TCLTKSYS=win
    elif [ $_HOST_TAG = darwin-x86 -o $_HOST_TAG = darwin-x86_64 ] ; then
         TCLTKSYS=unix
#         TCLTKSYS=macosx
    else
        TCLTKSYS=unix
    fi

    if [ ! -f $_PREFIX/include/tk.h ] ; then

        TCLTKVER=8.5.11
        if [ $_HOST_TAG = windows-x86 -o $_HOST_TAG = windows-x86_64 ] ; then
            # Originally I wanted to build tcltk statically, but a compiled .rc file needs to
            # be linked with the target program or dll (_tkinter.pyd here) for this to work.
            TCLTKSHAREDSTATIC="--disable-static --enable-shared"
        elif [ $_HOST_TAG = darwin-x86 -o $_HOST_TAG = darwin-x86_64 ] ; then
            TCLTKSHAREDSTATIC="--disable-shared --enable-static --disable-framework"
            TCLTKVER=8.6b2
        else
            TCLTKSHAREDSTATIC="--enable-shared --disable-static"
        fi

        HOST_SRC_DIR=${SRC_DIR}-${_HOST_TAG}
        mkdir -p ${HOST_SRC_DIR}
        download_package http://prdownloads.sourceforge.net/tcl/tcl${TCLTKVER}-src.tar.gz ${HOST_SRC_DIR}
        download_package http://prdownloads.sourceforge.net/tcl/tk${TCLTKVER}-src.tar.gz ${HOST_SRC_DIR}

        (
        cd ${HOST_SRC_DIR}/tcl${TCLTKVER}/$TCLTKSYS
        ./configure --prefix=$_PREFIX --exec-prefix=$_PREFIX $TCLTKSHAREDSTATIC $_BUILD $_HOST > configure.log 2>&1
        make -j$NUM_JOBS > make.log 2>&1
        make install > install.log 2>&1
        )
        (
        cd ${HOST_SRC_DIR}/tk${TCLTKVER}/$TCLTKSYS
        ./configure --prefix=$_PREFIX --exec-prefix=$_PREFIX $TCLTKSHAREDSTATIC $_BUILD $_HOST > configure.log 2>&1
        make -j$NUM_JOBS > make.log 2>&1
        make install > install.log 2>&1
        )
    fi
    # For 3.3.0, LDFLAGS_TCLTK and CFLAGS_TCLTK are not needed as _sysconfigdata.py has
    # the values but it shouldn't hurt either. LDFLAGS_TCLTK is added to LDSHARED.
    LDFLAGS_TCLTK="-L$_PREFIX/lib"
    CFLAGS_TCLTK="-I$_PREFIX/include"
    if [ $_HOST_TAG = linux-x86 -o $_HOST_TAG = linux-x86_64 ] ; then
        LDFLAGS_TCLTK=$LDFLAGS_TCLTK" -Wl,-rpath,$_PREFIX/lib/"
    fi
}

python_dependencies_build ()
{
    local _HOST=$1
    local _PREFIXSTATIC=$2
    local _PREFIXFINAL=$3

    dump "python_dependencies_build PDCURSES_RL=$PDCURSES_RL TCLTK=$TCLTK _HOST=$_HOST"

    # For windows...
    if [ $_HOST = windows-x86 -o $_HOST = windows-x86_64 ] ; then
#        if [ "$PDCURSES_RL" = "yes" ] ; then
# ncurses cross compile fails, see status.txt for (some) details.
#            make_ncurses $_HOST $_PREFIXSTATIC
            make_pdcurses $_HOST $_PREFIXSTATIC
#        fi
    fi

# GPL issues with this.
    if [ ! $_HOST = darwin-x86 -a ! $_HOST = darwin-x86_64 ] ; then
        make_readline $_HOST $_PREFIXSTATIC
#        make_editline $_HOST $_PREFIXSTATIC $_PREFIXFINAL
    fi

    # For all hosts...
#    if [ "$TCLTK" = "yes" ] ; then
        make_tcltk $_HOST $_PREFIXFINAL "--build=$BH_BUILD_CONFIG" "--host=$BH_HOST_CONFIG"
#    fi
}

python_dependencies_unpack ()
{
    local _HOST=$1
    local _PREFIXSTATIC=$2
    local _PREFIXFINAL=$3
    local _WHOSLIBS=$4

    if [ ! -d ${_PREFIXSTATIC} ] ; then
        mkdir -p ${_PREFIXSTATIC}
    fi
    download_package ${HOME}/Dropbox/Python/${_WHOSLIBS}.static.libs.tar.bz2 ${_PREFIXSTATIC}
}


# $1: host system tag
# $2: python version
build_host_python ()
{
    local SRCDIR=$SRC_DIR/Python-$2
    local BUILDDIR=$BH_BUILD_DIR/build-python-$1-$2
    local INSTALLDIR=$(python_build_install_dir $1 $2)
    local TEMPINSTALLDIR=${INSTALLDIR}_static_libs

    local ARGS TEXT

    setup_default_log_file $BUILDDIR/build.log

    if [ ! -f "$SRCDIR/configure" ]; then
        panic "Missing configure script in $SRCDIR"
    fi
    
    # Currently, 3.3.0 builds generate $SRCDIR/Lib/_sysconfigdata.py, unless it already
    # exists (in which case it ends up wrong)... this should really be in the build
    # directory instead, and I think Roumen had patches for that, but I don't think they
    # work.
    if [ ! -f "$SRCDIR/Lib/_sysconfigdata.py" ]; then
        log "Removing old $SRCDIR/Lib/_sysconfigdata.py"
        rm -f $SRCDIR/Lib/_sysconfigdata.py
    fi

    ARGS=" --prefix=$INSTALLDIR"

    # Python considers it cross compiling if --host is passed # ??? SHOULD THIS BE --build ???
    #  and that then requires that a CONFIG_SITE file is used.
    # This is not necessary if it's only the arch that differs.
    if [ ! $BH_HOST_CONFIG = $BH_BUILD_CONFIG -o "$BH_HOST_CONFIG" = "i586-pc-mingw32msvc" ] ; then
        ARGS=$ARGS" --build=$BH_BUILD_CONFIG"
    fi
    ARGS=$ARGS" --host=$BH_HOST_CONFIG"
    ARGS=$ARGS" $PYDEBUG"
#    ARGS=$ARGS" --disable-ipv6"

    mkdir -p "$BUILDDIR" && rm -rf "$BUILDDIR"/*
    cd "$BUILDDIR" &&
    bh_setup_host_env

    LDFLAGS_TCLTK=
    python_dependencies_build $1 $TEMPINSTALLDIR $INSTALLDIR

    CFG_SITE=
    export LDFLAGS="-L${TEMPINSTALLDIR}/lib"
    CFLAGS="$SAVE_TEMPS -I${TEMPINSTALLDIR}/include -I${TEMPINSTALLDIR}/include/ncursesw"
    CXXFLAGS="$CFLAGS"
    if [ ! $BH_HOST_TAG = $BH_BUILD_TAG ]; then

        # Cross compiling.
        CFG_SITE=$BUILDDIR/config.site

        # Ideally would remove all of these configury hacks by
        # patching the issues.

        if [ $1 = darwin-x86 -o $1 = darwin-x86_64 ]; then
            echo "ac_cv_file__dev_ptmx=no"              > $CFG_SITE
            echo "ac_cv_file__dev_ptc=no"              >> $CFG_SITE
            echo "ac_cv_have_long_long_format=yes"     >> $CFG_SITE
            if [ $1 = darwin-x86 ] ; then
                echo "ac_osx_32bit=yes"                >> $CFG_SITE
            elif [ $1 = darwin-x86_64 ] ; then
                echo "ac_osx_32bit=no"                 >> $CFG_SITE
            fi
            echo "ac_cv_have_sendfile=no"              >> $CFG_SITE
        elif [ $1 = windows-x86 -o $1 = windows-x86_64 ]; then
            echo "ac_cv_file__dev_ptmx=no"              > $CFG_SITE
            echo "ac_cv_file__dev_ptc=no"              >> $CFG_SITE
        elif [ $1 = linux-x86 -o $1 = linux-x86_64 ]; then
            echo "ac_cv_file__dev_ptmx=yes"             > $CFG_SITE
            echo "ac_cv_file__dev_ptc=no"              >> $CFG_SITE
            echo "ac_cv_have_long_long_format=yes"     >> $CFG_SITE
            echo "ac_cv_pthread_system_supported=yes"  >> $CFG_SITE
            echo "ac_cv_working_tzset=yes"             >> $CFG_SITE
            echo "ac_cv_little_endian_double=yes"      >> $CFG_SITE
        fi

        if [ $BH_HOST_OS = $BH_BUILD_OS ]; then
            # Only cross compiling from arch perspective.
            # qemu causes failures as cross-compilation is not detected
            # if a test executable can be run successfully, so we test
            # for qemu-${BH_HOST_ARCH} and qemu-${BH_HOST_ARCH}-static
            # and panic if either are found.
            QEMU_HOST_ARCH=$(arch_to_qemu_arch $BH_HOST_ARCH)
            if [ ! -z "$(which qemu-$QEMU_HOST_ARCH 2>/dev/null)" -o \
                 ! -z "$(which qemu-$QEMU_HOST_ARCH-static 2>/dev/null)" ] ; then
               panic "Installed qemu(s) ($(which qemu-$QEMU_HOST_ARCH 2>/dev/null) $(which qemu-$QEMU_HOST_ARCH-static 2>/dev/null))" \
                      "will prevent this build from working."
            fi
        fi
    fi

    dump "BH_BUILD_TAG is $BH_BUILD_TAG, BH_HOST_TAG is $BH_HOST_TAG, dollar 1 is $1"
    if [ $BH_BUILD_TAG = windows-x86_64 -o $BH_BUILD_TAG = windows-x86 ] ; then
     # Bit of a hack for running natively on MinGW where python.exe tries to run
      # our toolchain wrapper shell script via CreateProcess (and of course fails)
      # Another option is to set:
      #  CC  to $(dirname $(which gcc.exe)/gcc.exe
      #  CXX to $(dirname $(which g++.exe)/g++.exe
      pushd $(dirname $(which sh.exe))
      export CC="$(pwd -W)/sh.exe $CC"
      export CXX="$(pwd -W)/sh.exe $CXX"
      dump "exported CC of $CC"
      popd
    fi

    CFLAGS=$CFLAGS" $CFLAGS_TCLTK"
    LDSHARED="$CC $LDFLAGS_TCLTK"
    if [ $1 = darwin-x86 -o $1 = darwin-x86_64 ]; then
        # I could change AC_MSG_CHECKING(LDSHARED) in configure.ac
        # to check $host instead of $ac_sys_system/$ac_sys_release
        # but it handles loads of platforms
        # and I can only test on three, so instead...
        export LDSHARED=$LDSHARED "-bundle -undefined dynamic_lookup"
    elif [ $1 = windows-x86 -o $1 = windows-x86_64 ]; then
        local _WINTHREADS=$(mingw_threading_cflag)
        ARGS=$ARGS" $(mingw_threading_configure_arg)"
        CFLAGS=$CFLAGS" -D__USE_MINGW_ANSI_STDIO=1 $_WINTHREADS"
        CXXFLAGS=$CXXFLAGS" -D__USE_MINGW_ANSI_STDIO=1 $_WINTHREADS"
        # Need to add -L$HOST_STATIC_LIBDIR to LDSHARED if need
        # any static host libs.
        export LDSHARED=$LDSHARED" -shared $_WINTHREADS"
    elif [ $1 = linux-x86 -o $1 = linux-x86_64 ]; then
        export LDSHARED=$LDSHARED" -shared "
    fi

    TEXT="$(bh_host_text) python-$BH_HOST_CONFIG:"

    touch $SRCDIR/Include/graminit.h
    touch $SRCDIR/Python/graminit.c
    echo "" > $SRCDIR/Parser/pgen.stamp

    touch $SRCDIR/Parser/Python.asdl
    touch $SRCDIR/Parser/asdl.py
    touch $SRCDIR/Parser/asdl_c.py
    touch $SRCDIR/Include/Python-ast.h
    touch $SRCDIR/Python/Python-ast.c

    dump "$TEXT Building"
    export CONFIG_SITE=$CFG_SITE &&
    run2 "$SRCDIR"/configure $ARGS &&
# sharedmods is a phony target, but it's a dependency of both "make all" and also
# "make install", this causes it to fail on Windows as it tries to rename pydoc3
# to pydoc3.3 twice, and the second time aroud the file exists. So instead, we
# just do make install.

    # Can't run make install with -j as from the Makefile:
    # install:	 altinstall bininstall maninstall 
    #  meaning altinstall and bininstall are kicked off at the same time
    #  but actually, bininstall depends on altinstall being run first
    #  due to libainstall: doing
    #  $(INSTALL_SCRIPT) python-config $(DESTDIR)$(BINDIR)/python$(VERSION)-config
    #  and bininstall: doing
    #  (cd $(DESTDIR)$(BINDIR); $(LN) -s python$(VERSION)-config python2-config)
    #  Though the real fix is to simply make bininstall depend on libainstall.

    # For Python 3.3.0, without 0080-MINGW-hack-around-double-copy-scripts-issue.patch
    # a second run build_scripts fails as the target file exists.
    run2 make -j$NUM_JOBS
    run2 make install
}

need_build_host_python ()
{
    bh_stamps_do host-python-$1-$2 build_host_python $1 $2
}

# Install host Python binaries and support files to the NDK install dir.
# $1: host tag
# $2: python version
install_host_python ()
{
    local SRCDIR="$(python_build_install_dir $1 $2)"
    local DSTDIR="$NDK_DIR/$(python_ndk_install_dir $1 $2)"

    need_build_host_python $1 $2

    dump "$(bh_host_text) python-$BH_HOST_ARCH-$2: Installing"
    run copy_directory "$SRCDIR/bin"     "$DSTDIR/bin"
    run copy_directory "$SRCDIR/lib"     "$DSTDIR/lib"
    run copy_directory "$SRCDIR/share"   "$DSTDIR/share"
    run copy_directory "$SRCDIR/include" "$DSTDIR/include"
}

need_install_host_python ()
{
    local SRCDIR="$(python_build_install_dir $1 $2)"

    bh_stamps_do install-host-python-$1-$2 install_host_python $1 $2

    # make sharedmods (setup.py) needs to use the build machine's Python
    # for the other hosts to build correctly.
    if [ $BH_BUILD_TAG = $BH_HOST_TAG ]; then
        export PATH=$SRCDIR/bin:$PATH
    fi
}

# Package host Python binaries into a tarball
# $1: host tag
# $2: python version
package_host_python ()
{
    local SRCDIR="$(python_ndk_install_dir $1 $2)"
    local PACKAGENAME=$(python_ndk_package_name $1 $2)-$1.tar.bz2
    local PACKAGE="$PACKAGE_DIR/$PACKAGENAME"

    need_install_host_python $1 $2

    dump "$(bh_host_text) $PACKAGENAME: Packaging"
    run pack_archive "$PACKAGE" "$NDK_DIR" "$SRCDIR"
}

PYTHON_VERSION=$(commas_to_spaces $PYTHON_VERSION)
ARCHS=$(commas_to_spaces $ARCHS)

# Let's build this
for SYSTEM in $BH_HOST_SYSTEMS; do
    bh_setup_build_for_host $SYSTEM
    for VERSION in $PYTHON_VERSION; do
        need_install_host_python $SYSTEM $VERSION
    done
done

if [ "$PACKAGE_DIR" ]; then
    for SYSTEM in $BH_HOST_SYSTEMS; do
        bh_setup_build_for_host $SYSTEM
        for VERSION in $PYTHON_VERSION; do
            package_host_python $SYSTEM $VERSION
        done
    done
fi
