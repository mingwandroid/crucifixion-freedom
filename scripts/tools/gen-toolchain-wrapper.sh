#!/bin/sh
#
# Copyright (C) 2012 The Android Open Source Project
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
#  This shell script is used to rebuild the gcc and toolchain binaries
#  for the Android NDK.
#

PROGDIR=$(dirname "$0")
. "$PROGDIR/prebuilt-common.sh"

PROGRAM_PARAMETERS="<dst-dir>"
PROGRAM_DESCRIPTION="\
This script allows you to generate a 'wrapper toolchain', i.e. a set of
simple scripts that act as toolchain binaries (e.g. my-cc, my-c++, my-ld,
etc...) but call another installed toolchain instead, possibly with additional
command-line options.

For example, imagine we want a toolchain that generates 32-bit binaries while
running on a 64-bit system, we could call this script as:

   $PROGNAME --cflags="-m32" --cxxflags="-m32" --ldflags="-m32" /tmp/my-toolchain

Then, this will create programs like:

   /tmp/my-toolchain/my-cc
   /tmp/my-toolchain/my-gcc
   /tmp/my-toolchain/my-c++
   /tmp/my-toolchain/my-g++
   /tmp/my-toolchain/my-ld
   ...

Where the compilers and linkers will add the -m32 flag to the command-line before
calling the host version of 'cc', 'gcc', etc...

Generally speaking:

  - The 'destination toolchain' is the one that will be called by the
    generated wrapper script. It is identified by a 'destination prefix'
    (e.g. 'x86_64-linux-gnu-', note the dash at the end).

    If is empty by default, but can be changed with --dst-prefix=<prefix>

  - The 'source prefix' is the prefix added to the generated toolchain scripts,
    it is 'my-' by default, but can be changed with --src-prefix=<prefix>

  - You can use --cflags, --cxxflags, --ldflags, etc... to add extra
    command-line flags for the generated compiler, linker, etc.. scripts

"

DEFAULT_SRC_PREFIX="my-"
DEFAULT_DST_PREFIX=""

SRC_PREFIX=$DEFAULT_SRC_PREFIX
register_var_option "--src-prefix=<prefix>" SRC_PREFIX "Set source toolchain prefix"

DST_PREFIX=$DEFAULT_DST_PREFIX
register_var_option "--dst-prefix=<prefix>" DST_PREFIX "Set destination toolchain prefix"

EXTRA_CFLAGS=
register_var_option "--cflags=<options>" EXTRA_CFLAGS "Add extra C compiler flags"

EXTRA_CXXFLAGS=
register_var_option "--cxxflags=<options>" EXTRA_CXXFLAGS "Add extra C++ compiler flags"

EXTRA_LDFLAGS=
register_var_option "--ldflags=<options>" EXTRA_LDFLAGS "Add extra linker flags"

EXTRA_ASFLAGS=
register_var_option "--asflags=<options>" EXTRA_ASFLAGS "Add extra assembler flags"

EXTRA_ARFLAGS=
register_var_option "--arflags=<options>" EXTRA_ARFLAGS "Add extra archiver flags"

CCACHE=
register_var_option "--ccache=<prefix>" CCACHE "Use ccache compiler driver"

CC_OVERRIDE=gcc
register_var_option "--cc=<prefix>" CC_OVERRIDE "Use as c compiler"

CXX_OVERRIDE=g++
register_var_option "--cxx=<prefix>" CXX_OVERRIDE "Use as c++ compiler"

PROGRAMS="cc gcc c++ g++ cpp as ld ar ranlib strip strings nm objdump dlltool windres readelf"
register_var_option "--programs=<list>" PROGRAMS "List of programs to generate wrapper for"

extract_parameters "$@"

PROGRAMS=$(commas_to_spaces "$PROGRAMS")
if [ -z "$PROGRAMS" ]; then
    panic "Empty program list, nothing to do!"
fi

DST_DIR="$PARAMETERS"
if [ -z "$DST_DIR" ]; then
    panic "Please provide a destination directory as a parameter! See --help for details."
fi

mkdir -p "$DST_DIR"
fail_panic "Could not create destination directory: $DST_DIR"

# Generate a small wrapper program
#
# $1: program name, without any prefix (e.g. gcc, g++, ar, etc..)
# $2: source prefix (e.g. 'i586-mingw32msvc-')
# $3: destination prefix (e.g. 'i586-px-mingw32msvc-')
# $4: destination directory for the generate program
#
gen_wrapper_program ()
{
    local PROG="$1"
    local SRC_PREFIX="$2"
    local DST_PREFIX="$3"
    local DST_FILE="$4/${SRC_PREFIX}$PROG"
    local FLAGS=""

    DST_PROG=$PROG
    case $PROG in
      cc|gcc) FLAGS=$FLAGS" $EXTRA_CFLAGS"; DST_PROG=$CC_OVERRIDE;;
      c++|g++) FLAGS=$FLAGS" $EXTRA_CXXFLAGS";  DST_PROG=$CXX_OVERRIDE;;
      ar) FLAGS=$FLAGS" $EXTRA_ARFLAGS";;
      as) FLAGS=$FLAGS" $EXTRA_ASFLAGS";;
      ld|ld.bfd|ld.gold) FLAGS=$FLAGS" $EXTRA_LDFLAGS";;
      windres)
        # Due to a bug in MinGW-w64 x86-64 windres:
        # https://sourceforge.net/tracker/?func=detail&aid=3588309&group_id=202880&atid=983354
        FLAGS=$FLAGS" --use-temp-file"
        # Should pass -F flag value in instead of having it depend on the value of EXTRA_CFLAGS
        case $EXTRA_CFLAGS in
          *-m32*)
              FLAGS=$FLAGS" -F pe-i386"
              ;;
          *-m64*)
              FLAGS=$FLAGS" -F pe-x86-64"
              ;;
        esac
        ;;
    esac
    if [ -n "$CCACHE" ]; then
        DST_PREFIX=$CCACHE" "$DST_PREFIX
    fi

    cat > "$DST_FILE" << EOF
#!/bin/sh
# Auto-generated, do not edit
${DST_PREFIX}$DST_PROG $FLAGS "\$@"
EOF
    chmod +x "$DST_FILE"
    log "Generating: ${SRC_PREFIX}$PROG"
}

log "Generating toolchain wrappers in: $DST_DIR"


for PROG in $PROGRAMS; do
  if [ -f ${DST_PREFIX}$PROG ] || [ -f ${DST_PREFIX}${PROG}.exe ] ; then
    gen_wrapper_program $PROG "$SRC_PREFIX" "$DST_PREFIX" "$DST_DIR"
  elif [ -f $(dirname ${DST_PREFIX})/$PROG ] || [ -f $(dirname ${DST_PREFIX})/${PROG}.exe ] ; then
    # mingw-w64 native has 'ar' and 'as' even though the rest are all prefixed.
    gen_wrapper_program $PROG "$SRC_PREFIX" "$(dirname ${DST_PREFIX})/" "$DST_DIR"
  else
    # catches the case of no DST_PREFIX at all, e.g. just gcc.
    gen_wrapper_program $PROG "$SRC_PREFIX" "$DST_PREFIX" "$DST_DIR"
  fi
done

log "Done!"
