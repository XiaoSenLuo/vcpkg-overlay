@echo off
setlocal EnableDelayedExpansion
rem Deploy this overlay repository into a vcpkg installation:
rem   ports\      -> %VCPKG_ROOT%\overlay\ports
rem   toolchains\ -> %VCPKG_ROOT%\scripts\toolchains
rem   triplets\   -> %VCPKG_ROOT%\triplets
rem Existing files with the same name are renamed to <file-name>.origin;
rem --restore deletes the deployed files and renames the *.origin ones back.
rem
rem Usage: deploy-overlay.bat --vcpkg-root <path> [--restore]
rem
rem Note: the subroutines below never use "call" inside a "for" block --
rem cmd.exe corrupts the loop context in that case (iterations run twice
rem or get skipped). All per-file work is therefore inlined.

set "SCRIPT_DIR=%~dp0"
set "VCPKG_ROOT="
set "RESTORE=0"

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--vcpkg-root" goto arg_root
if /i "%~1"=="--restore" goto arg_restore
if /i "%~1"=="--help" goto usage_ok
if /i "%~1"=="-h" goto usage_ok
echo error: unknown option: %~1
call :usage
exit /b 2

:arg_root
if "%~2"=="" (
    echo error: --vcpkg-root requires a value
    exit /b 2
)
set "VCPKG_ROOT=%~2"
shift
shift
goto parse_args

:arg_restore
set "RESTORE=1"
shift
goto parse_args

:usage_ok
call :usage
exit /b 0

:args_done
if defined VCPKG_ROOT goto check_root
echo error: --vcpkg-root is not specified.
echo Please install vcpkg first (https://github.com/microsoft/vcpkg),
echo then pass its root directory with --vcpkg-root ^<path^>.
exit /b 1

:check_root
if exist "%VCPKG_ROOT%\scripts\toolchains\" goto root_ok
echo error: "%VCPKG_ROOT%" is not a vcpkg root (scripts\toolchains not found).
exit /b 1

:root_ok
set /a N_COPIED=0
set /a N_RESERVED=0
set /a N_REMOVED=0
set /a N_RESTORED=0

if "%RESTORE%"=="1" goto do_restore

dir /s /b "%VCPKG_ROOT%\overlay\ports\*.origin" "%VCPKG_ROOT%\scripts\toolchains\*.origin" "%VCPKG_ROOT%\triplets\*.origin" 2>nul | findstr /i "\.origin$" >nul
if not errorlevel 1 (
    echo error: found *.origin backups left by a previous deploy.
    echo Run "deploy-overlay.bat --vcpkg-root <path> --restore" first, then deploy again.
    exit /b 1
)

call :deploy_tree "%SCRIPT_DIR%ports" "%VCPKG_ROOT%\overlay\ports"
if errorlevel 1 exit /b 1
call :deploy_tree "%SCRIPT_DIR%toolchains" "%VCPKG_ROOT%\scripts\toolchains"
if errorlevel 1 exit /b 1
call :deploy_tree "%SCRIPT_DIR%triplets" "%VCPKG_ROOT%\triplets"
if errorlevel 1 exit /b 1
echo deploy finished: copied !N_COPIED! file(s), reserved !N_RESERVED! original(s) as *.origin
exit /b 0

:do_restore
call :restore_tree "%SCRIPT_DIR%ports" "%VCPKG_ROOT%\overlay\ports"
if errorlevel 1 exit /b 1
call :restore_tree "%SCRIPT_DIR%toolchains" "%VCPKG_ROOT%\scripts\toolchains"
if errorlevel 1 exit /b 1
call :restore_tree "%SCRIPT_DIR%triplets" "%VCPKG_ROOT%\triplets"
if errorlevel 1 exit /b 1
call :cleanup_empty "%VCPKG_ROOT%\overlay\ports"
call :try_rmdir "%VCPKG_ROOT%\overlay\ports"
call :try_rmdir "%VCPKG_ROOT%\overlay"
call :cleanup_empty "%VCPKG_ROOT%\scripts\toolchains"
call :cleanup_empty "%VCPKG_ROOT%\triplets"
echo restore finished: removed !N_REMOVED! file(s), restored !N_RESTORED! backup(s)
exit /b 0

:usage
echo Usage: deploy-overlay.bat --vcpkg-root ^<path^> [--restore]
echo   --vcpkg-root ^<path^>  vcpkg installation root directory (required)
echo   --restore            remove deployed files and restore *.origin backups
exit /b 0

:deploy_tree
rem %1 = source directory, %2 = destination directory
set "DT_SRC=%~1"
set "DT_DST=%~2"
for /r "%DT_SRC%" %%F in (*) do (
    set "DT_FULL=%%~fF"
    set "DT_REL=!DT_FULL:%DT_SRC%\=!"
    set "DT_TARGET=%DT_DST%\!DT_REL!"
    rem create the parent directory, reserving a blocking file if needed
    for %%Z in ("!DT_TARGET!") do set "DT_PDIR=%%~dpZ"
    if not exist "!DT_PDIR!\" (
        if exist "!DT_PDIR!" if not exist "!DT_PDIR!.origin" (
            for %%P in ("!DT_PDIR!") do ren "!DT_PDIR!" "%%~nxP.origin"
            echo reserved: "!DT_PDIR!" -^> "!DT_PDIR!.origin"
            set /a N_RESERVED+=1
        )
        mkdir "!DT_PDIR!"
    )
    rem reserve an existing destination entry with the same name
    if exist "!DT_TARGET!.origin" (
        echo note: "!DT_TARGET!.origin" already exists, keeping it
    ) else if exist "!DT_TARGET!" (
        ren "!DT_TARGET!" "%%~nxF.origin"
        if errorlevel 1 (
            echo error: failed to reserve "!DT_TARGET!"
            exit /b 1
        )
        echo reserved: "!DT_TARGET!" -^> "!DT_TARGET!.origin"
        set /a N_RESERVED+=1
    )
    copy /y "%%~fF" "!DT_TARGET!" >nul
    if errorlevel 1 (
        echo error: failed to copy "%%~fF"
        exit /b 1
    )
    echo copied: "%%~fF" -^> "!DT_TARGET!"
    set /a N_COPIED+=1
)
exit /b 0

:restore_tree
rem %1 = source directory, %2 = destination directory
set "RT_SRC=%~1"
set "RT_DST=%~2"
if not exist "%RT_DST%\" exit /b 0
for /r "%RT_SRC%" %%F in (*) do (
    set "RT_FULL=%%~fF"
    set "RT_REL=!RT_FULL:%RT_SRC%\=!"
    set "RT_TARGET=%RT_DST%\!RT_REL!"
    if exist "!RT_TARGET!" (
        if exist "!RT_TARGET!\*" (
            rd /s /q "!RT_TARGET!"
        ) else (
            del /f /q "!RT_TARGET!" >nul 2>&1
        )
        if exist "!RT_TARGET!" (
            echo error: failed to remove "!RT_TARGET!"
            exit /b 1
        )
        echo removed: "!RT_TARGET!"
        set /a N_REMOVED+=1
    )
    if exist "!RT_TARGET!.origin" (
        ren "!RT_TARGET!.origin" "%%~nxF"
        if errorlevel 1 (
            echo error: failed to restore "!RT_TARGET!.origin"
            exit /b 1
        )
        echo restored: "!RT_TARGET!.origin" -^> "!RT_TARGET!"
        set /a N_RESTORED+=1
    )
)
exit /b 0

:cleanup_empty
rem %1 = root directory; removes empty sub-directories (root itself is kept)
set "CE_ROOT=%~1"
if not exist "%CE_ROOT%\" exit /b 0
:cleanup_loop
set /a CE_CHANGED=0
for /f "delims=" %%D in ('dir /s /b /ad "%CE_ROOT%" 2^>nul') do (
    if /i not "%%D"=="%CE_ROOT%" (
        dir /b /a "%%D" 2>nul | findstr . >nul
        if errorlevel 1 (
            rd "%%D" 2>nul && set /a CE_CHANGED=1
        )
    )
)
if "%CE_CHANGED%"=="1" goto cleanup_loop
exit /b 0

:try_rmdir
rem removes %1 only if it is an empty directory
if exist "%~1\" rd "%~1" >nul 2>&1
exit /b 0
