@echo off
setlocal enabledelayedexpansion

:: Set the title for the command window
title ArtTic-LAB Installer

:: --- Configuration ---
set "ENV_NAME=ArtTic-LAB"
set "PYTHON_VERSION=3.11"

:: --- Main Script ---
:main
cls
echo =======================================================
echo             ArtTic-LAB Installer for Windows
echo =======================================================
echo.
echo This script will find your Conda installation and prepare
echo the '%ENV_NAME%' environment.
echo.

:: 1. Find and initialize Conda
call :find_conda
if errorlevel 1 (
    echo [ERROR] Conda installation not found.
    echo Please ensure Miniconda, Anaconda, or Miniforge is installed and accessible.
    pause
    exit /b 1
)

:: 2. Handle environment creation
echo.
echo [INFO] Checking for existing '%ENV_NAME%' environment...
conda env list | findstr /B /C:"%ENV_NAME% " >nul
if not errorlevel 1 (
    echo [WARNING] Environment '%ENV_NAME%' already exists.
    set /p "REINSTALL=Do you want to remove and reinstall it? (y/n): "
    if /i not "!REINSTALL!"=="y" (
        echo [INFO] Skipping environment creation. Will update packages.
        goto install_packages
    )
)

call :create_environment
if errorlevel 1 (
    echo [FATAL ERROR] Could not create the Conda environment.
    pause
    exit /b 1
)

:install_packages
echo.
echo [INFO] Activating environment and installing/updating dependencies...
echo This is the longest step. Please be patient.
call conda activate %ENV_NAME%
if errorlevel 1 (
    echo [ERROR] Failed to activate Conda environment.
    pause
    exit /b 1
)

echo [INFO] Upgrading pip...
python -m pip install --upgrade pip --quiet
if errorlevel 1 ( echo [ERROR] Failed to upgrade pip. & pause & exit /b 1 )

echo.
echo Please select your hardware for PyTorch installation:
echo   1. NVIDIA (CUDA)
echo   2. Intel GPU (XPU)
echo   3. CPU only
echo.
set /p "HARDWARE_CHOICE=Enter your choice (1, 2, or 3): "

if "!HARDWARE_CHOICE!"=="1" (
    pip install torch torchvision torchaudio
) else if "!HARDWARE_CHOICE!"=="2" (
    pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/xpu
    pip install intel-extension-for-pytorch==2.8.10+xpu --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
) else if "!HARDWARE_CHOICE!"=="3" (
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    pip install intel-extension-for-pytorch --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/cpu/us/
) else (
    echo [ERROR] Invalid choice. Aborting.
    pause
    exit /b 1
)
if errorlevel 1 ( echo [ERROR] PyTorch installation failed. & pause & exit /b 1 )

echo [INFO] Installing other dependencies from requirements.txt...
pip install -r requirements.txt
if errorlevel 1 ( echo [ERROR] Installation of other dependencies failed. & pause & exit /b 1 )

call :handle_hf_login

echo.
echo =======================================================
echo [SUCCESS] Installation complete!
echo You can now run 'start.bat' to launch ArtTic-LAB.
echo =======================================================
echo.
pause
exit /b 0


:: --- Subroutines ---
:find_conda
:: This robustly finds Conda by checking if it's already active,
:: then searching common paths for Miniconda, Anaconda, and Miniforge.
:: It will prompt the user if multiple installations are found.

:: 1. Best case: Conda is already available in the shell
if defined CONDA_EXE (
    echo [INFO] Conda is already initialized in this shell.
    exit /b 0
)

:: 2. Search for Conda installations and store their paths
set "conda_count=0"

:: Check common USER paths
if exist "%USERPROFILE%\miniconda3\condabin\conda.bat" (
    set "conda_paths[!conda_count!]=%USERPROFILE%\miniconda3"
    set /a conda_count+=1
)
if exist "%USERPROFILE%\anaconda3\condabin\conda.bat" (
    set "conda_paths[!conda_count!]=%USERPROFILE%\anaconda3"
    set /a conda_count+=1
)
if exist "%USERPROFILE%\AppData\Local\miniforge3\condabin\conda.bat" (
    set "conda_paths[!conda_count!]=%USERPROFILE%\AppData\Local\miniforge3"
    set /a conda_count+=1
)

:: Check common SYSTEM paths (ProgramData)
if exist "%ProgramData%\Miniconda3\condabin\conda.bat" (
    set "conda_paths[!conda_count!]=%ProgramData%\Miniconda3"
    set /a conda_count+=1
)
if exist "%ProgramData%\Anaconda3\condabin\conda.bat" (
    set "conda_paths[!conda_count!]=%ProgramData%\Anaconda3"
    set /a conda_count+=1
)
if exist "%ProgramData%\Miniforge3\condabin\conda.bat" (
    set "conda_paths[!conda_count!]=%ProgramData%\Miniforge3"
    set /a conda_count+=1
)

:: 3. Process the findings
if !conda_count! equ 0 (
    :: No installations found
    exit /b 1
)

if !conda_count! equ 1 (
    :: Exactly one installation found, use it automatically
    set "conda_path=!conda_paths[0]!"
    echo [SUCCESS] Found single Conda installation at: !conda_path!
) else (
    :: Multiple installations found, prompt user to choose
    echo.
    echo [WARNING] Multiple Conda installations detected. Please choose which one to use:
    for /l %%i in (0,1,!conda_count!-1) do (
        set /a "display_num=%%i+1"
        echo   !display_num!. !conda_paths[%%i]!
    )
    echo.
    :get_choice
    set "CONDA_CHOICE="
    set /p "CONDA_CHOICE=Enter your choice (1-!conda_count!): "
    if not defined CONDA_CHOICE goto get_choice
    if !CONDA_CHOICE! GTR !conda_count! (echo Invalid choice. Try again.& goto get_choice)
    if !CONDA_CHOICE! LSS 1 (echo Invalid choice. Try again.& goto get_choice)

    set /a "choice_index=!CONDA_CHOICE!-1"
    call set "conda_path=%%conda_paths[!choice_index!]%%"
    echo [INFO] You selected: !conda_path!
)

:: 4. Initialize the chosen Conda environment
set "ACTIVATE_SCRIPT=!conda_path!\Scripts\activate.bat"
if not exist "!ACTIVATE_SCRIPT!" (
    echo [ERROR] Could not find 'activate.bat' in the selected installation: !conda_path!
    exit /b 1
)

echo [INFO] Initializing Conda from: !ACTIVATE_SCRIPT!
call "!ACTIVATE_SCRIPT!"
exit /b 0


:create_environment
echo.
echo -------------------------------------------------------
echo [INFO] Creating Conda environment with Python %PYTHON_VERSION%...
echo -------------------------------------------------------
echo [INFO] Removing any previous version of '%ENV_NAME%'...
call conda env remove --name "%ENV_NAME%" -y >nul 2>nul
echo [INFO] Creating new Conda environment...
call conda create --name "%ENV_NAME%" python=%PYTHON_VERSION% -y
if errorlevel 1 exit /b 1
exit /b 0

:handle_hf_login
echo.
echo -------------------------------------------------------
echo [ACTION REQUIRED] Hugging Face Login
echo -------------------------------------------------------
echo Models like SD3 and FLUX require you to be logged into
echo your Hugging Face account to download base files.
echo.
set /p "LOGIN_CHOICE=Would you like to log in now? (y/n): "
if /i "!LOGIN_CHOICE!"=="y" (
    echo.
    echo [INFO] Please get your Hugging Face User Access Token here:
    echo        https://huggingface.co/settings/tokens
    echo [INFO] The token needs at least 'read' permissions.
    echo.
    huggingface-cli login
    echo.
    echo [IMPORTANT] Remember to visit the model pages on the
    echo Hugging Face website to accept their license agreements:
    echo - SD3: https://huggingface.co/stabilityai/stable-diffusion-3-medium-diffusers
    echo - FLUX: https://huggingface.co/black-forest-labs/FLUX.1-dev
    echo.
) else (
    echo.
    echo [INFO] Skipping Hugging Face login.
    echo You can log in later by opening a terminal, running
    echo 'conda activate %ENV_NAME%' and then 'huggingface-cli login'.
    echo Note: SD3 and FLUX models will not work until you do.
)
exit /b 0