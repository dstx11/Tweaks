@echo off
setlocal EnableExtensions
title DSTX Tweaks v0.8.3 - Local Release Build

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\ci\build-release.ps1"
pause
