@echo off
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "GODOT_EXE=C:\Users\Ajiry\Downloads\Compressed\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT_EXE%" (
    where godot >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        set "GODOT_EXE=godot"
    ) else (
        echo Godot executable tidak ditemukan!
        pause
        exit /b 1
    )
)

echo Menjalankan Starter Kit City Builder...
start "" "%GODOT_EXE%" --path "%SCRIPT_DIR%"
