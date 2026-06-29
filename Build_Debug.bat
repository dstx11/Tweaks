@echo off
setlocal
title DSTX Tweaks v0.8 - Build Debug
cd /d "%~dp0DSTX.Tweaks.App"
dotnet build
pause
