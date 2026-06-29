@echo off
setlocal
title DSTX Tweaks v0.8 - Publish Self Contained x64
cd /d "%~dp0DSTX.Tweaks.App"
dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=false
pause
