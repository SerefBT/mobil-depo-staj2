@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uygulama\CD-Kur.ps1" %*
if errorlevel 1 (echo Kurulum tamamlanamadi. Yukaridaki mesaji kontrol edin. & pause & exit /b 1)
