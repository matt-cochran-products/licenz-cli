@echo off
REM licenz installer for Windows CMD
REM This is a wrapper that calls the PowerShell installer

echo Installing licenz...
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/matt-cochran/licenz-cli/main/install.ps1 | iex"
