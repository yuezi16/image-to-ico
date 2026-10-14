@echo off
chcp 65001 >nul
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0ImageToIco.ps1"
if errorlevel 1 pause
