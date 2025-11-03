@echo off
setlocal
title ArtTic-LAB

echo [INFO] Preparing to launch ArtTic-LAB...

rem --- 1. Find Conda Installation ---
set "CONDA_BASE_PATH="
where conda.exe >nul 2>nul && (for /f "delims=" %%i in ('where conda.exe') do set "CONDA_EXE_PATH=%%i" & goto FoundCondaPath)

rem Check User Paths
if exist "%USERPROFILE%\miniconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%USERPROFILE%\miniconda3" & goto FoundCondaPath
if exist "%USERPROFILE%\anaconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%USERPROFILE%\anaconda3" & goto FoundCondaPath
if exist "%USERPROFILE%\AppData\Local\miniforge3\condabin\conda.bat" set "CONDA_BASE_PATH=%USERPROFILE%\AppData\Local\miniforge3" & goto FoundCondaPath

rem Check System Paths
if exist "%ProgramData%\Miniconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%ProgramData%\Miniconda3" & goto FoundCondaPath
if exist "%ProgramData%\Anaconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%ProgramData%\Anaconda3" & goto FoundCondaPath
if exist "%ProgramData%\Miniforge3\condabin\conda.bat" set "CONDA_BASE_PATH=%ProgramData%\Miniforge3" & goto FoundCondaPath

goto NoConda

:FoundCondaPath
if not defined CONDA_BASE_PATH (
    for %%i in ("%CONDA_EXE_PATH%") do (
        set "CONDA_SCRIPTS_DIR=%%~dpi"
        for %%j in ("!CONDA_SCRIPTS_DIR!..") do set "CONDA_BASE_PATH=%%~fj"
    )
)
echo [INFO] Conda found at: %CONDA_BASE_PATH%

rem --- 2. Initialize Conda & Verify Environment ---
call "%CONDA_BASE_PATH%\Scripts\activate.bat"
if %errorlevel% neq 0 goto InitFail

echo [INFO] Checking for 'ArtTic-LAB' environment...
conda env list | findstr /I /B "ArtTic-LAB " >nul
if %errorlevel% neq 0 goto EnvNotFound

echo [INFO] Activating environment...
call conda activate ArtTic-LAB
if %errorlevel% neq 0 goto ActivateFail

rem --- 3. Launch Application ---
echo [SUCCESS] Environment activated. Launching application...
echo.
echo =======================================================
echo              Launching ArtTic-LAB
echo =======================================================
echo.

python app.py %*

echo.
echo =======================================================
echo ArtTic-LAB has closed.
echo =======================================================
goto End

:NoConda
echo.
echo [ERROR] Conda installation not found.
echo Please ensure Miniconda, Anaconda, or Miniforge is installed and run install.bat.
goto End

:InitFail
echo.
echo [ERROR] Failed to initialize the Conda command environment.
echo Your Conda installation might be corrupted.
goto End

:EnvNotFound
echo.
echo [ERROR] The 'ArtTic-LAB' environment was not found.
echo Please run the 'install.bat' script first to set it up.
goto End

:ActivateFail
echo.
echo [ERROR] Failed to activate the 'ArtTic-LAB' environment.
echo The environment may be corrupted. Please try running 'install.bat' again.
goto End

:End
echo.
echo Press any key to exit this window.
pause >nul
endlocal