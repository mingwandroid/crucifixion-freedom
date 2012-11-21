    ' This script sets up a MinGW64 and MSYS environment.
    ' I've had enough of MinGW32 and it's lack of features
    ' (where is crtdbg.h etc etc) or cross-platform support.

    dim WshShell
    set WshShell = WScript.CreateObject("WScript.Shell")
    WshShell.CurrentDirectory = WshShell.ExpandEnvironmentStrings("%TEMP%")
    verbose = 0

    function unZip(zipFilePath,destFolder)
        dim FSO
        dim oApp
        dim strDate

        if verbose = 1 then
            msgbox "hmm zfp " & zipFilePath & " df " & destFolder
        end if
        set FSO = CreateObject("Scripting.FileSystemObject")
        if not FSO.FolderExists(destFolder) then
            FSO.CreateFolder(destFolder)
        end if

        'Extract the files into the newly created folder
        Set oApp = CreateObject( "Shell.Application" )
        Set objSource = oApp.NameSpace(zipFilePath).Items()
        Set objTarget = oApp.NameSpace(destFolder)
        objTarget.CopyHere objSource, 256

        On Error Resume Next
        Set FSO = CreateObject("scripting.filesystemobject")
        FSO.deletefolder Environ("Temp") & "\Temporary Directory*", True
    end function

    function downloadHTTP(sourceUrl,destFilepath)
        dim xmlhttp
        if verbose = 1 then
            msgbox "downloadHTTP sourceUrl " & sourceUrl & " destFilepath " & destFilepath
        end if
        set xmlhttp=createobject("MSXML2.XMLHTTP.3.0")
        'xmlhttp.SetOption 2, 13056 'If https -> Ignore all SSL errors
        xmlhttp.Open "GET", sourceUrl, false
        xmlhttp.Send
        if verbosea = 1 then
            Wscript.Echo "Download-Status: " & xmlhttp.Status & " " & xmlhttp.statusText
        end if
        if xmlhttp.Status = 200 then
            dim objStream
            set objStream = CreateObject("ADODB.Stream")
            objStream.Type = 1 'adTypeBinary
            objStream.Open
            objStream.Write xmlhttp.responseBody
            objStream.SaveToFile destFilepath, 2
            objStream.Close
        end if
        downloadHTTP=destFilepath
    end function

    function downloadUnpack(sourceUrl,destFolder)
        names=Split(sourceUrl, "/")
        if verbose = 1 then
            msgbox "sourceUrl Split is " & names(Ubound(names))
        end if
        destFile = WshShell.ExpandEnvironmentStrings("%TEMP%") & "\" & names(Ubound(names))
        destFile = downloadHTTP(sourceUrl,destFile)
        if verbose = 1 then
            msgbox "downloadUnpack " & destFile
        end if
        run "cmd /c " & Temp7zaExe & " x " & destFile & " -y"
        'Now remove the filepath bit and also the .lzma/.7z bit'
        names=Split(destFile, "\")
        filePart=names(Ubound(names))
        names=Split(destFile, ".")
        result=""
        for counter = 0 To UBound(names)-1
           result=result & names(counter)
           if counter < UBound(names)-1 Then
               result=result & "."
           end if
        Next
        if verbose = 1 then
            msgbox "cmd /c " & Temp7zaExe & " x " & result & " -y -o" & Dest & "\msys"
        end if
        run "cmd /c " & Temp7zaExe & " x " & result & " -y -o" & Dest & "\msys"
    end function
 
    function run(ByVal command)
        dim shell
        set shell = CreateObject("WScript.Shell")
        shell.Run command, 1, true
    end function

    function copy(source,dest)
        dim FSO
        set FSO = CreateObject("Scripting.FileSystemObject")
        FSO.CopyFile source, dest
    end function

    function move(source,dest)
        dim FSO
        set FSO = CreateObject("Scripting.FileSystemObject")
        if FSO.FolderExists(source) then
            FSO.MoveFolder source, dest
        end if
    end function

    Dest = InputBox("Please Enter Destination Folder")
    set FSO = CreateObject("Scripting.FileSystemObject")
    if not FSO.FolderExists(Dest) then
        FSO.CreateFolder(Dest)
    end if

    MinGW64_sourceforge = "http://garr.dl.sourceforge.net/project/mingw-w64"
    MinGW64_32_filename = "i686-w64-mingw32-gcc-4.7.2-release-win32_rubenvb.7z"
    MinGW64_32_destfile = WshShell.CurrentDirectory & "\" & MinGW64_32_filename
    MinGW64_64_filename = "x86_64-w64-mingw32-gcc-4.7.2-release-win64_rubenvb.7z"
    MinGW64_64_destfile = WshShell.CurrentDirectory & "\" & MinGW64_64_filename

    SevenZaZip = WshShell.CurrentDirectory & "\7za920.zip"
    TempDir = WshShell.CurrentDirectory & "\Temp7za"
    MinGW64_32 = WshShell.CurrentDirectory & "\" & MinGW64_32_filename
    MinGW64_64 = WshShell.CurrentDirectory & "\" & MinGW64_64_filename 

    downloadHTTP "http://garr.dl.sourceforge.net/project/sevenzip/7-Zip/9.20/7za920.zip", SevenZaZip
    unZip SevenZaZip, TempDir
    Temp7zaExe = TempDir & "\7za.exe"

    downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/Base/xz/xz-5.0.3-1/xz-5.0.3-1-msys-1.0.17-bin.tar.lzma", Dest & "\msys"
    downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/Base/xz/xz-5.0.3-1/liblzma-5.0.3-1-msys-1.0.17-dll-5.tar.lzma", Dest & "\msys"

    downloadHTTP MinGW64_sourceforge & "/Toolchains targetting Win32/Personal Builds/rubenvb/gcc-4.7-release/" & MinGW64_32_filename, MinGW64_32_destfile
    downloadHTTP MinGW64_sourceforge & "/Toolchains targetting Win64/Personal Builds/rubenvb/gcc-4.7-release/" & MinGW64_64_filename, MinGW64_64_destfile

    ' The top level folders in each archive is different (mingw32, mingw64) so for this question to
    ' be worthwhile I'd have to deliberately mix them, which is probably asking for problems.
    'result = msgbox("Do you want the default GCC to be 64bit?", vbYesNo, "Choose GCC Architecture")
    'if result = vbYes then
      ' Extract win32 then win64.
      run "cmd /c " & Temp7zaExe & " x " & MinGW64_32_destfile & " -y -o" & Dest
      run "cmd /c " & Temp7zaExe & " x " & MinGW64_64_destfile & " -y -o" & Dest
    'else
    '  ' Extract win64 then win32.
    '  run "cmd /c " & Temp7zaExe & " x " & MinGW64_64_destfile & " -y -o" & Dest
    '  run "cmd /c " & Temp7zaExe & " x " & MinGW64_32_destfile & " -y -o" & Dest
    'end if

    result = msgbox("Yes installs msysgit (MSYS with git)" & Chr(10) & "No installs MSYS (32-bit) from mingw-w64 project", vbYesNo, "Do you want Git with your MSYS?")
    if result = vbYes then
      'MsysGit_file = "msysGit-netinstall-1.7.11-preview20120620.exe"'
      MsysGit_file = "Git-1.7.11-preview20120704.exe"
      MsysGit_filename = "http://msysgit.googlecode.com/files/" & MsysGit_file
      MinMsysGit_destfile = WshShell.CurrentDirectory & "\" & MsysGit_file
      downloadHTTP MsysGit_filename, MinMsysGit_destfile
      MsysGitInstallCmd = MinMsysGit_destfile & " /SILENT /DIR=" & Dest & "\msys"
      run "cmd /c " & MsysGitInstallCmd

      'Also need msys gnumake here'
      MsysMake_destfile = WshShell.CurrentDirectory & "\" & "make-3.81-3-msys-1.0.13-bin.tar.lzma"
      downloadHTTP "http://garr.dl.sourceforge.net/project/mingw/MSYS/Base/make/make-3.81-3/make-3.81-3-msys-1.0.13-bin.tar.lzma", MsysMake_destfile
      run "cmd /c " & Temp7zaExe & " x " & MsysMake_destfile & " -y"
      run "cmd /c " & Temp7zaExe & " x " & "make-3.81-3-msys-1.0.13-bin.tar" & " -y -o" & Dest & "\msys"
    else
      MinGW64_Msys_filename = "MSYS-20111123.zip"
      MinGW64_Msys_destfile = WshShell.CurrentDirectory & "\" & MinGW64_Msys_filename
      downloadHTTP MinGW64_sourceforge & "/External binary packages (Win64 hosted)/MSYS (32-bit)/" & MinGW64_Msys_filename, MinGW64_Msys_destfile
      unZip MinGW64_Msys_destfile, Dest
      downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/Base/findutils/findutils-4.4.2-2/findutils-4.4.2-2-msys-1.0.13-bin.tar.lzma", Dest & "\msys"
    end if

    downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/Base/xz/xz-5.0.3-1/xz-5.0.3-1-msys-1.0.17-bin.tar.lzma", Dest & "\msys"

    result = msgbox("Do you need" & Chr(10) & "MSYS-autoconf, MSYS-texinfo, MSYS-libintl, MSYS-libiconv, MSYS-grep?" & Chr(10) & "(if you installed msys-git, you probably do)", vbYesNo, "Install MSYS shell dev tools?")
    if result = vbYes then
      downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/msysdev/autoconf/autoconf-2.68-1/autoconf-2.68-1-msys-1.0.17-bin.tar.lzma", Dest & "\msys"
      downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/Base/texinfo/texinfo-4.13a-2/texinfo-4.13a-2-msys-1.0.13-bin.tar.lzma", Dest & "\msys"
      downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/Base/gettext/gettext-0.18.1.1-1/libintl-0.18.1.1-1-msys-1.0.17-dll-8.tar.lzma", Dest & "\msys"
      downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/Base/libiconv/libiconv-1.14-1/libiconv-1.14-1-msys-1.0.17-dll-2.tar.lzma", Dest & "\msys"
      downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/Base/grep/grep-2.5.4-2/grep-2.5.4-2-msys-1.0.13-bin.tar.lzma", Dest & "\msys"
    end if

    result = msgbox("Do you need MSYS-binutils," & Chr(10) & "MSYS-gcc, MSYS-coredev and MSYS-w32api?" & Chr(10) & "Hint: unless you plan to develop" & Chr(10) & "MSYS tools, you don't", vbYesNo, "Install MSYS developer tools?")
    if result = vbYes then
        downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/msysdev/binutils/binutils-2.19.51-3/binutils-2.19.51-3-msys-1.0.13-bin.tar.lzma", Dest & "\msys"
        downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/msysdev/gcc/gcc-3.4.4-3/gcc-3.4.4-3-msys-1.0.13-bin.tar.lzma", Dest & "\msys"
        downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/Base/msys-core/msys-1.0.17-1/msysCORE-1.0.17-1-msys-1.0.17-dev.tar.lzma", Dest & "\msys"
        downloadUnpack "http://garr.dl.sourceforge.net/project/mingw/MSYS/msysdev/w32api/w32api-3.14-3/w32api-3.14-3-msys-1.0.12-dev.tar.lzma", Dest & "\msys"
    end if

    ' Write Dest & \msys\etc\fstab with either "Dest & \mingw32 /mingw" or "Dest & \mingw64 /mingw"
    result = msgbox("Do you want the default GCC to be 64bit?", vbYesNo, "Choose GCC Architecture")
    if result = vbYes then
      MinGWRealFolder = Dest & "\" & "mingw64"
    else
      MinGWRealFolder = Dest & "\" & "mingw32"
    end if
    FstabMingw=MinGWRealFolder & " /mingw"
    Const ForWriting = 2
    Const OpenAsASCII = 0
    Const CreateIfNotExist = True
    ' Specify output file.
    strFile = Dest & "\msys\etc\fstab"

    ' Open the file.
    Set objFSO = CreateObject("Scripting.FileSystemObject")
    Set objFile = objFSO.OpenTextFile(strFile, ForWriting, CreateIfNotExist, OpenAsASCII)
    objFile.WriteLine FstabMingw
    objFile.close

    result = msgbox("Do you want to make a symlink from C:\mingw to " & MinGWRealFolder, vbYesNo, "Symlink")
    if result = vbYes then
        if FSO.FolderExists("C:\mingw") then
            result = msgbox("C:\mingw already exists! Are you sure?", vbYesNo, "Symlink (again)")
            if result = vbYes then
                do while FSO.FolderExists("C:\mingw")
                    FSO.DeleteFolder "C:\mingw"
                loop
            end if
        end if
        if result = vbYes then
            run "cmd /c mklink /D C:\mingw " & MinGWRealFolder
        end if
    end if

    ' Download some newer or better versions of some tools'
    'wget is stdio (--) compat with ssl'
    'expr is from coreutils-8.17 compiled for MSYS'
    downloadHTTP "http://mingw-and-ndk.googlecode.com/files/wget.exe", Dest & "\msys\bin\wget.exe"
    downloadHTTP "http://mingw-and-ndk.googlecode.com/files/expr.exe", Dest & "\msys\bin\expr.exe"
    'And copy 7za over too'
    copy Temp7zaExe, Dest & "\msys\bin\"
