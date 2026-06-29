@echo off
setlocal EnableExtensions
title DSTX Tweaks - Run installed dstx.exe

set "APP=%ProgramFiles%\DSTX Tweaks\dstx.exe"
if not exist "%APP%" (
  echo DSTX Tweaks is not installed yet.
  echo Run Install_Build_Run_DSTX_Tweaks.bat first.
  pause
  exit /b 1
)

powershell -NoProfile -Command "Start-Process -FilePath '%APP%' -Verb RunAs"
