#!/bin/sh

THISDIR=$(dirname "$0")

patch -p1 < $THISDIR/0005-MINGW.patch
git add . && git commit -a -m \
"MinGW-w64: Initial MinGW(-w64) feature patch.

(by Roumen Petrov and LRN)."

patch -p1 < $THISDIR/0006-mingw-removal-of-libffi-patch.patch
git add . && git commit -a -m \
"MinGW-w64: Removal of the libffi changes.

Done this way so that Roumen's and Alexey's
patches can be updated more easily."


patch -p1 < $THISDIR/0007-mingw-system-libffi.patch
git add . && git commit -a -m \
"MinGW-w64: --with-system-ffi now looks for ffi.h.

Windows 64 fixes for ffi.
Some ctypes fixes for MinGW(-w64).
(by Alexey Pavlov)."


patch -p1 < $THISDIR/0010-mingw-osdefs-DELIM.patch
git add . && git commit -a -m \
"MinGW-w64: Add autoconf variable DELIM

..which is the path delimiter to use. Usually a colon
but on Windows a semi-colon."


patch -p1 < $THISDIR/0015-mingw-use-posix-getpath.patch
git add . && git commit -a -m \
"MinGW-w64: Switch to using the Posix getpath code

..in Modules/getpathp.c rather than the Windows version
in PC/getpath.c. This is because we want the Posix
file layout."


patch -p1 < $THISDIR/0020-mingw-w64-test-for-REPARSE_DATA_BUFFER.patch
git add . && git commit -a -m \
"MinGW-w64: Compile fix for REPARSE_DATA_BUFFER

..which is not declared in the MinGW-w64 headers."


patch -p1 < $THISDIR/0025-mingw-regen-with-stddef-instead.patch
git add . && git commit -a -m \
"MinGW-w64: Use a different header for regen

..because /usr/include/netinet/in.h doesn't exist.
Instead we use include/stddef.h from the GCC installation,
located via -print-search-dirs trickery."


patch -p1 < $THISDIR/0030-mingw-add-libraries-for-_msi.patch
git add . && git commit -a -m \
"MinGW-w64: Enable building the _msi module.

Note, this isn't enough for msi, but it's a good start."


patch -p1 < $THISDIR/0035-MSYS-add-MSYSVPATH-AC_ARG.patch
git add . && git commit -a -m \
"MSYS: Add building on MSYSVPATH configure argument.

When building on MSYS, VPATH ends up containing
an un-translated path which then falls over in
distutils. So MSYSVPATH is VPATH translated to
the Windows version and this is passed to disutils
instead."


patch -p1 < $THISDIR/0040-mingw-cygwinccompiler-use-CC-envvars-and-ld-from-print-prog-name.patch
git add . && git commit -a -m \
"Distutils (cygwinccompiler): Use CC and LD env. variables

..also, if gcc is found then override LD with the output
from 'CC --print-prog-name ld'"


patch -p1 < $THISDIR/0045-cross-darwin.patch
git add . && git commit -a -m \
"Darwin: Enable as a target for cross compilation."


patch -p1 < $THISDIR/0050-mingw-sysconfig-like-posix.patch
git add . && git commit -a -m \
"MinGW-w64: Adopt unix filesystem layout for MinGW Python."


patch -p1 < $THISDIR/0055-mingw-pdcurses_ISPAD.patch
git add . && git commit -a -m \
"MinGW-w64: Add ISPAD define so that PDCurses can be used."


patch -p1 < $THISDIR/0060-mingw-static-tcltk.patch
git add . && git commit -a -m \
"MinGW-w64: Allow static tcltk (which I don't recommend)."


patch -p1 < $THISDIR/0065-mingw-x86_64-size_t-format-specifier-pid_t.patch
git add . && git commit -a -m \
"MinGW-w64: Allow size_t (%z) format specifier.

Also, remove the error:
Python doesn't support sizeof(pid_t) > sizeof(long)
because it does on Win64 where long is only 32 bit."


patch -p1 < $THISDIR/0070-python-disable-dbm.patch
git add . && git commit -a -m \
"MinGW-w64: Don't compile dbm module."


patch -p1 < $THISDIR/0075-add-python-config-sh.patch
git add . && git commit -a -m \
"Cross: Add python-config.sh.

Generate and use python-config.sh, which is a shell script
replacement for python-config which can therefore be used
in cross compilation scenarios."


patch -p1 < $THISDIR/0080-mingw-nt-threads-vs-pthreads.patch
git add . && git commit -a -m \
"MinGW-w64: Allow either nt-threads and pthreads.

I only ever build with nt-threads, and will continue to do so
until I'm convinced winpthreads is fully working, but having
the option is useful."


patch -p1 < $THISDIR/0085-cross-dont-add-multiarch-paths-if.patch
git add . && git commit -a -m \
"Cross: Don't add multi-arch paths if cross compiling."


patch -p1 < $THISDIR/0090-mingw-reorder-bininstall-ln-symlink-creation.patch
git add . && git commit -a -m \
"MSYS: Fix ln -s ordering

..as when ln is really cp, as on MSYS, the source must exist
before creating any links to it."


patch -p1 < $THISDIR/0095-mingw-use-backslashes-in-compileall-py.patch
git add . && git commit -a -m \
"MinGW-w64: Replace forwardslashes with backslashes

..in compileall.py"


patch -p1 < $THISDIR/0100-mingw-distutils-MSYS-convert_path-fix-and-root-hack.patch
git add . && git commit -a -m \
"MSYS distutils: Path conversion for --root option.

Converts --root=<MSYS/path> to --root=<Windows/path>
as our Python is Windows native.

Added a hack to convert_path because
os.path.join(['C:','folder','subfolder']) returns:
'C:folder\subfolder'
..which isn't the same as:
'C:\folder\subfolder'"


patch -p1 < $THISDIR/0105-mingw-MSYS-no-usr-lib-or-usr-include.patch
git add . && git commit -a -m \
"MinGW-w64/MSYS: Do not search build system sysroot folders.

/usr/include or /usr/lib must not be added to the search path
as they are MSYS system paths, not MinGW-w64 system paths."


patch -p1 < $THISDIR/0110-mingw-_PyNode_SizeOf-decl-fix.patch
git add . && git commit -a -m \
"MinGW-w64: Simple compile fix."


patch -p1 < $THISDIR/0115-mingw-cross-includes-lower-case.patch
git add . && git commit -a -m \
"MinGW-w64 Cross: MinGW-w64 headers are all lowercase.

When running natively on Windows filesysems this doesn't matter,
but when cross compiling on a case-sensitive filesystem it does."


patch -p1 < $THISDIR/0500-mingw-install-LDLIBRARY-to-LIBPL-dir.patch
git add . && git commit -a -m \
"MinGW-w64: Installation fix for the shared Python library."


patch -p1 < $THISDIR/0505-add-build-sysroot-config-option.patch
git add . && git commit -a -m \
"MinGW-w64: Added --build-sysroot config option

..which I'm not so sure about the value of. CFLAGS and LDSHARED
are probably the right way to pass custom paths to distutils, but
it's not harmful to have this option."


patch -p1 < $THISDIR/0510-cross-PYTHON_FOR_BUILD-gteq-275-and-fullpath-it.patch
git add . && git commit -a -m \
"Cross: Use full path for the cross Python interpreter

..and ensure it is version 2.7.5 or greater."


patch -p1 < $THISDIR/0515-mingw-add-GetModuleFileName-path-to-PATH.patch
git add . && git commit -a -m \
"MinGW-w64: Add path of python.exe or python2.7.dll to PATH

..so that other dlls can be placed in the same location and loaded
correctly. This is used for example, when loading the shared tcltk."


patch -p1 < $THISDIR/0520-Add-interp-Python-DESTSHARED-to-PYTHONPATH-b4-pybuilddir-txt-dir.patch
git add . && git commit -a -m \
"Add the build machine's Python's DESTSHARED path to PYTHONPATH

..before the path contained in pybuilddir.txt so that the shared
modules for the host machine don't get loaded incorrectly during
make install."

patch -p1 < $THISDIR/0525-msys-monkeypatch-os-system-via-sh-exe.patch
git add . && git commit -a -m \
"MSYS: Apply a monkeypatch to os.system

..so that the commands are run through sh.exe so that shell
indirection to /dev/null and other things requiring a Posix
shell work as expected."


patch -p1 < $THISDIR/9999-re-configure-d.patch
git add . && git commit -a -m \
"Python 2.7.5: Regen configure and pyconfig.h.in"
