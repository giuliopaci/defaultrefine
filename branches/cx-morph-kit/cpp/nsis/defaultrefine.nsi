!include Library.nsh

Name "Default Refine library"
OutFile "defaultrefine-setup.exe"
InstallDir "$PROGRAMFILES\defaultrefine"
InstallDirRegKey HKLM "SOFTWARE\defaultrefine" "Install_Dir"
Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Default Refine Library (required)"
    SectionIn RO
    setOutPath $INSTDIR
    WriteRegStr HKLM "SOFTWARE\defaultrefine" "Install_Dir" "$INSTDIR"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\defaultrefine" "DisplayName" "Default Refine Library"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\defaultrefine" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\defaultrefine" "NoModify" 1
    WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\defaultrefine" "NoRepair" 1
    WriteUninstaller "uninstall.exe"
    !insertmacro InstallLib REGDLL 0 REBOOT_NOTPROTECTED ..\msvc\vc10\WinG2PDll\Release\WinG2PDLL.dll $SYSDIR\WinG2PDLL.dll $SYSDIR
    MessageBox MB_YESNO "The Default Refine library depends on Microsoft Visual Studio C++ 8.0 library files.  Unless you have Visual Studio C++ 2010 installed on your computer, you must install these support files for the Default Refine library to work properly.  Do you want to install Visual Studio C++ 8.0 Support files?" IDNO endVS8
        File "vcredist_x86.8.exe"
        ExecWait "$INSTDIR\vcredist_x86.8.exe"
    endVS8:
    MessageBox MB_YESNO "The Default Refine library also depends on Microsoft Visual Studio C++ 10.0 library files.  Unless you have Visual Studio C++ 2010 installed on your computer, you must install these support files for the Default Refine library to work properly.  Do you want to install Visual Studio C++ 10.0 Support files?" IDNO endVS10
        File "vcredist_x86.10.exe"
        ExecWait "$INSTDIR\vcredist_x86.10.exe"
    endVS10:
    MessageBox MB_YESNO "Would you like to install the Default and Refine Python extension module?" IDNO endPython
        File "..\..\python\dist\g2p-1.0.win32.msi"
        ExecWait '"msiexec" /i "$INSTDIR\g2p-1.0.win32.msi"'
    endPython:
SectionEnd

Section "Uninstall"
  DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\defaultrefine"
  DeleteRegKey HKLM "SOFTWARE\defaultrefine"
  RMDir /r "$INSTDIR"
  Delete /REBOOTOK $SYSDIR\WinG2PDLL.dll
SectionEnd
