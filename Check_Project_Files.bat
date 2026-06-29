@echo off
setlocal
title DSTX Tweaks v0.8 - Check Files
if not exist "%~dp0DSTX.Tweaks.App\DSTX.Tweaks.App.csproj" echo Missing csproj
if not exist "%~dp0catalog\tweaks.catalog.json" echo Missing tweaks catalog
if not exist "%~dp0scripts\run-action.ps1" echo Missing runner script
echo Done.
pause
