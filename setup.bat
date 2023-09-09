@ECHO OFF
TITLE Setup
ECHO -- Options
CHOICE /M "Create desktop shortcut? [Y] Yes, [N] No" /N
SET CREATE_SHORTCUT=1
IF ERRORLEVEL 2 SET CREATE_SHORTCUT=0
ECHO -- Installing...
SET CURRENT_FOLDER=%~dp0
IF EXIST "%USERPROFILE%\Documents\WindowsPowershell\Modules\CSShell" (
  CHOICE /M "The module is already installed. Reinstall? [Y] Yes, [N] No" /N
  IF ERRORLEVEL 2 EXIT /B
  RMDIR "%USERPROFILE%\Documents\WindowsPowershell\Modules\CSShell" /S /Q
)
ECHO Creating directories
FOR %%A IN ("%USERPROFILE%\Documents\WindowsPowershell", "%USERPROFILE%\Documents\WindowsPowershell\Modules", "%USERPROFILE%\Documents\WindowsPowershell\Modules\CSShell") DO (
  ECHO %%~A
  IF NOT EXIST %%A MD %%A
)
ECHO Copying files
XCOPY "%~dp0*" "%USERPROFILE%\Documents\WindowsPowershell\Modules\CSShell\" /E
IF ERRORLEVEL 1 (
  ECHO Installation failed!
  PAUSE>nul
  EXIT /B
)
ECHO Deleting setup file in destination path
DEL "%USERPROFILE%\Documents\WindowsPowershell\Modules\CSShell\%~nx0"
IF %CREATE_SHORTCUT%==1 (
  ECHO Creating shortcut
  COPY "%USERPROFILE%\Documents\WindowsPowershell\Modules\CSShell\CSShell.lnk" "%USERPROFILE%\Desktop\"
)
ECHO -- Installation complete!
CHOICE /M "Start now? [Y] Yes, [N] No" /N
IF ERRORLEVEL 2 EXIT /B
START "" "%USERPROFILE%\Documents\WindowsPowershell\Modules\CSShell\CSShell.lnk"
