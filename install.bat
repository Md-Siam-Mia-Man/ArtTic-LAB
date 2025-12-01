@echo off
setlocal EnableDelayedExpansion

rem --- Configuration ---
set "ENV_NAME=ArtTic-LAB"
set "PYTHON_VERSION=3.11"

rem --- Main Script ---
cls
echo =======================================================
echo             ArtTic-LAB Installer for Windows
echo =======================================================
echo.
echo This script will find your Conda installation and prepare
echo the "%ENV_NAME%" environment.
echo.

rem 1. Find Conda installation robustly
echo [INFO] Searching for Conda installation...
set "CONDA_BASE_PATH="
if exist "%USERPROFILE%\miniforge3\condabin\conda.bat" set "CONDA_BASE_PATH=%USERPROFILE%\miniforge3"
if exist "%USERPROFILE%\Miniconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%USERPROFILE%\Miniconda3"
if exist "%USERPROFILE%\anaconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%USERPROFILE%\anaconda3"
if exist "%ProgramData%\miniforge3\condabin\conda.bat" set "CONDA_BASE_PATH=%ProgramData%\miniforge3"
if exist "%ProgramData%\Miniconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%ProgramData%\Miniconda3"
if exist "%ProgramData%\anaconda3\condabin\conda.bat" set "CONDA_BASE_PATH=%ProgramData%\anaconda3"

if not defined CONDA_BASE_PATH (
    echo [ERROR] Could not find Conda. Please ensure Miniconda, Anaconda, or Miniforge is installed in a standard location.
    pause
    exit /b 1
)
echo [SUCCESS] Found Conda at: %CONDA_BASE_PATH%
set "ACTIVATE_BAT=%CONDA_BASE_PATH%\Scripts\activate.bat"

rem 2. Initialize Conda for this script session
echo [INFO] Initializing Conda for this session...
call "%ACTIVATE_BAT%" base
if %errorlevel% neq 0 (
    echo [ERROR] Failed to activate Conda base environment.
    pause
    exit /b 1
)

rem 3. Handle environment creation
echo.
echo [INFO] Checking for existing "%ENV_NAME%" environment...
call conda env list | findstr /B /C:"%ENV_NAME% " >nul
if %errorlevel% equ 0 (
    echo [WARNING] Environment "%ENV_NAME%" already exists.
    choice /c yn /m "Do you want to remove and reinstall it? (y/n):"
    if errorlevel 2 (
        echo [INFO] Skipping environment creation. Will update packages.
    ) else (
        echo [INFO] Removing previous version of "%ENV_NAME%"...
        call conda env remove --name "%ENV_NAME%" -y >nul 2>&1
        echo [INFO] Creating new Conda environment...
        call conda create --name "%ENV_NAME%" python=%PYTHON_VERSION% -y
    )
) else (
    echo [INFO] Creating new Conda environment...
    call conda create --name "%ENV_NAME%" python=%PYTHON_VERSION% -y
)

rem 4. Activate environment and install packages
echo.
echo [INFO] Activating environment and installing dependencies...
echo This is the longest step. Please be patient.
call conda activate "%ENV_NAME%"

echo [INFO] Upgrading pip...
python -m pip install --upgrade pip --quiet

echo [INFO] Installing base dependencies from requirements.txt...
pip install -r requirements.txt

echo.
echo [INFO] Automatically detecting hardware for PyTorch installation...

rem Create a temporary python script to avoid batch nesting quote issues
(
echo from torchruntime.device_db import get_gpus
echo from torchruntime.platform_detection import get_torch_platform
echo print(get_torch_platform(get_gpus(^)^)^)
) > _detect_hw.py

set "TORCH_PLATFORM="
for /f "tokens=*" %%i in ('python _detect_hw.py') do set "TORCH_PLATFORM=%%i"
del _detect_hw.py

if not defined TORCH_PLATFORM (
    echo [ERROR] torchruntime failed to detect hardware. Please check your drivers.
    pause
    exit /b 1
)
echo [INFO] Detected platform: %TORCH_PLATFORM%
echo [INFO] Installing hardware-specific dependencies...

set "IS_CUDA="
echo %TORCH_PLATFORM% | findstr /B "cu" >nul && set "IS_CUDA=true"

if /I "%TORCH_PLATFORM%"=="xpu" (
    pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/xpu
    pip install intel-extension-for-pytorch==2.8.10+xpu --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
) else if defined IS_CUDA (
    pip install torch torchvision torchaudio
) else (
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    pip install intel-extension-for-pytorch --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/cpu/us/
)

rem 5. Install Web UI dependencies
echo.
echo [INFO] Installing Web UI dependencies...
where npm >nul 2>nul
if %errorlevel% neq 0 (
    echo [WARNING] npm (Node.js) is not installed or not in your PATH.
    echo Skipping automatic installation of UI icon packages.
    echo The UI will still work but will fetch icons from the web.
) else (
    if exist "web" (
        pushd web
        call npm install
        popd
    ) else (
        echo [WARNING] 'web' directory not found. Skipping npm install.
    )
)

rem 6. Handle Hugging Face Login
echo.
echo -------------------------------------------------------
echo [ACTION REQUIRED] Hugging Face Login
echo -------------------------------------------------------
echo Models like SD3 and FLUX require you to be logged into
echo your Hugging Face account to download base files.
echo.
set /p login_choice="Would you like to log in now? (y/n): "
if /i "%login_choice%"=="y" (
    echo.
    echo [INFO] Please get your Hugging Face User Access Token here:
    echo        https://huggingface.co/settings/tokens
    echo [INFO] The token needs at least 'read' permissions.
    echo.
    huggingface-cli login
    echo.
    echo [IMPORTANT] Remember to visit the model pages on the
    echo Hugging Face website to accept their license agreements.
    echo.
) else (
    echo.
    echo [INFO] Skipping Hugging Face login.
    echo You can log in later by opening a terminal, running
    echo 'conda activate %ENV_NAME%' and then 'huggingface-cli login'.
)

echo.
echo =======================================================
echo [SUCCESS] Installation complete!
echo You can now run 'start.bat' to launch ArtTic-LAB.
echo =======================================================
echo.
pause
endlocal