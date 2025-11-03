@echo off
setlocal

rem --- Configuration ---
set "ENV_NAME=ArtTic-LAB"

echo [INFO] Preparing to launch ArtTic-LAB...

rem 1. Find Conda installation
set "CONDA_BASE_PATH="
if exist "%USERPROFILE%\miniforge3\condabin\conda.bat" set "CONDA_BASE_PATH=%USERPROFILE%\miniforge3"
if exist "%USERPROFILE%\Miniconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%USERPROFILE%\Miniconda3"
if exist "%USERPROFILE%\anaconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%USERPROFILE%\anaconda3"
if exist "%ProgramData%\miniforge3\condabin\conda.bat" set "CONDA_BASE_PATH=%ProgramData%\miniforge3"
if exist "%ProgramData%\Miniconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%ProgramData%\Miniconda3"
if exist "%ProgramData%\anaconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%ProgramData%\anaconda3"

if not defined CONDA_BASE_PATH (
    echo [ERROR] Conda installation not found.
    echo Please ensure Miniconda, Anaconda, or Miniforge is installed and run install.bat.
    pause
    exit /b 1
)
echo [INFO] Conda found at: %CONDA_BASE_PATH%
set "ACTIVATE_BAT=%CONDA_BASE_PATH%\Scripts\activate.bat"

rem 2. Initialize Conda and Activate Environment
echo [INFO] Activating environment...
call "%ACTIVATE_BAT%" "%ENV_NAME%"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to activate the '%ENV_NAME%' environment.
    echo Please run 'install.bat' first to set it up.
    pause
    exit /b 1
)

rem 3. Launch the Application in a loop
:start_app
echo [SUCCESS] Environment activated. Launching application...
echo.
echo =======================================================
echo             Launching ArtTic-LAB
echo =======================================================
echo.

python app.py %*
set "exit_code=%errorlevel%"

if %exit_code% equ 21 (
    echo.
    echo [INFO] Restarting ArtTic-LAB...
    goto :start_app
)

echo.
echo =======================================================
echo ArtTic-LAB has closed.
echo =======================================================
echo.

endlocal
pause