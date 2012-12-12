crucifixion-freedom
===================

Cross compilation patches and build scripts for CPython

Contact: Ray Donnelly <mingw.android@gmail.com>

-----------------------
COPYRIGHTS AND LICENSES
-----------------------

 -------------
 Build Scripts
 -------------

 Copyright (C) 2012 The Android Open Source Project
 Copyright (C) 2012 Ray Donnelly

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

 -------
 Patches
 -------

 Copyright (C) 2010-2012 Roumen Petrov, Руслан Ижбулатов
 Copyright (C) 2012 Ray Donnelly, Алексей Павлов

-------
DETAILS
-------

This project is a scratch area for my Python cross compilation work.

One day I'll tidy it up and finish the configuration side of things.

I started this project to make it possible to cross compile GDB with
CPython integration.

------------------
USAGE INSTRUCTIONS
------------------

The build machine can be any of GNU/Linux, Windows and Darwin. The
host machine can be any of GNU/Linux, Windows and Darwin. Given the
current situation with respect to available cross compilers, the
following table illustrates which cross compilation combinations are
possible.

Build Machine:
GNU/Linux
Valid Hosts:
GNU/Linux,Windows,Darwin

Build Machine:
Windows
Valid Hosts:
Windows,Darwin

Build Machine:
Darwin
Valid Hosts:
Darwin

To setup a Windows (MinGW-w64 with MSYS) build environment, execute:
scripts/windows/BootstrapMinGW64.vbs

It'll ask you:
"Do you want Git with your MSYS?" Select Yes.
"Install MSYS shell dev tools?" Select Yes.
"Install MSYS developer tools?" Select No.
"Choose GCC Architecture, Do you want the default GCC to be 64bit?" Select No.
"Symlink" Select No.

To get cross compilers:
Windows: MinGW-w64 project (Ruben's personal toolchains)
Darwin:  http://code.google.com/p/mingw-and-ndk/downloads/list or
         https://github.com/mingwandroid/toolchain4

To target Darwin, you will need a fully working MacOSX SDK, usually
from an Xcode dmg. Care should to be taken when extracting these as
they contain symlinks and many extraction methods fail to handle
these correctly.

To build a nest of snakes given the right compilers on your PATH and
a Darwin SDK, execute:
./crucifixion-freedom.sh --python-version=2.7.3,3.3.0            \\
                                --systems=linux-x86,linux-x86_64 \\
                                      windows-x86,windows-x86_64 \\
                                        darwin-x86,darwin-x86_64 \\
                             --darwin-sdk=PATH_TO_MacOSX10.7.sdk

...cross your fingers and wait a long time.
