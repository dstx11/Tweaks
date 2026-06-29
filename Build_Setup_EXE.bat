@echo off
setlocal EnableExtensions
title DSTX Tweaks - Build final setup.exe

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\bootstrap-build-install-run.ps1" -BuildSetup
pause
