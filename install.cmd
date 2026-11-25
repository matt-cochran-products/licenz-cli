@echo off
REM licenz installer for Windows CMD
REM This is a wrapper that calls the PowerShell installer

echo Installing licenz...
powershell -ExecutionPolicy Bypass -Command "irm -MaximumRedirection 10 https://raw.githubusercontent.com/matt-cochran-products/licenz-cli/main/install.ps1 | iex"
