@echo off
setlocal

:: --- Configuration ---
set ENV_NAME=ArtTic-LAB
set PYTHON_VERSION=3.11

:: --- Subroutines (as goto labels) ---
:find_conda
    echo [INFO] Searching for Conda installation...
    
    :: 1. Best case: Conda is already available in the shell
    where conda >nul 2>nul
    if %errorlevel% equ 0 (
        echo [SUCCESS] Conda is already in your PATH.
        for /f "delims=" %%i in ('conda info --base') do set CONDA_BASE_PATH=%%i
        goto :conda_found
    )

    :: 2. Search common user paths
    if exist "%USERPROFILE%\miniconda3\condabin\conda.bat" (
        set CONDA_BASE_PATH=%USERPROFILE%\miniconda3
        goto :conda_found
    )
    if exist "%USERPROFILE%\anaconda3\condabin\conda.bat" (
        set CONDA_BASE_PATH=%USERPROFILE%\anaconda3
        goto :conda_found
    )

    goto :conda_not_found

:conda_found
    echo [INFO] Conda found at: %CONDA_BASE_PATH%
    call "%CONDA_BASE_PATH%\Scripts\activate.bat" base
    goto :eof

:conda_not_found
    echo [ERROR] Conda installation not found. Please ensure Miniconda or Anaconda is installed.
    exit /b 1

:create_environment
    echo.
    echo -------------------------------------------------------
    echo [INFO] Creating Conda environment with Python %PYTHON_VERSION%...
    echo -------------------------------------------------------
    
    echo [INFO] Removing any previous version of '%ENV_NAME%'...
    call conda env remove --name "%ENV_NAME%" -y >nul 2>nul
    
    echo [INFO] Creating new Conda environment...
    call conda create --name "%ENV_NAME%" python=%PYTHON_VERSION% -y
    goto :eof

:handle_hf_login
    echo.
    echo -------------------------------------------------------
    echo [ACTION REQUIRED] Hugging Face Login
    echo -------------------------------------------------------
    echo Models like SD3 and FLUX require you to be logged into
    echo your Hugging Face account to download base files.
    echo.
    
    choice /c yn /m "Would you like to log in now? (y/n): "
    if errorlevel 2 (
        echo.
        echo [INFO] Skipping Hugging Face login.
        echo You can log in later by opening a terminal, running
        echo 'conda activate %ENV_NAME%' and then 'huggingface-cli login'.
        echo Note: SD3 and FLUX models will not work until you do.
    ) else (
        echo.
        echo [INFO] Please get your Hugging Face User Access Token here:
        echo        https://huggingface.co/settings/tokens
        echo [INFO] The token needs at least 'read' permissions.
        echo.
        call huggingface-cli login
        echo.
        echo [IMPORTANT] Remember to visit the model pages on the
        echo Hugging Face website to accept their license agreements:
        echo - SD3: https://huggingface.co/stabilityai/stable-diffusion-3-medium-diffusers
        echo - FLUX: https://huggingface.co/black-forest-labs/FLUX.1-dev
        echo.
    )
    goto :eof


:: --- Main Script ---
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
if %errorlevel% neq 0 exit /b 1

:: 2. Handle environment creation
echo.
echo [INFO] Checking for existing '%ENV_NAME%' environment...
call conda env list | findstr /b /c:"%ENV_NAME% " >nul
if %errorlevel% equ 0 (
    echo [WARNING] Environment '%ENV_NAME%' already exists.
    choice /c yn /m "Do you want to remove and reinstall it? (y/n): "
    if errorlevel 2 (
        echo [INFO] Skipping environment creation. Will update packages.
    ) else (
        call :create_environment
    )
) else (
    call :create_environment
)

:: 3. Activate environment and install packages
echo.
echo [INFO] Activating environment and installing/updating dependencies...
echo This is the longest step. Please be patient.
call conda activate "%ENV_NAME%"

echo [INFO] Upgrading pip...
python -m pip install --upgrade pip --quiet

echo.
echo Please select your hardware for PyTorch installation:
echo   1. Intel GPU (XPU)
echo   2. NVIDIA (CUDA)
echo   3. CPU only
echo.
choice /c 123 /m "Enter your choice (1, 2, or 3): "
set hardware_choice=%errorlevel%

if %hardware_choice%==1 (
    pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/xpu
    pip install intel-extension-for-pytorch==2.8.10+xpu --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
)
if %hardware_choice%==2 (
    pip install torch torchvision torchaudio
)
if %hardware_choice%==3 (
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    pip install intel-extension-for-pytorch --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/cpu/us/
)

echo [INFO] Installing other dependencies from requirements.txt...
pip install -r requirements.txt

:: 4. Install Web UI dependencies
echo.
echo [INFO] Installing Web UI dependencies...
where npm >nul 2>nul
if %errorlevel% neq 0 (
    echo [WARNING] npm (Node.js) is not installed or not in your PATH.
    echo Skipping automatic installation of UI icon packages.
    echo The UI will still work but will fetch icons from the web.
) else (
    cd web
    call npm install
    cd ..
)

:: 5. Handle Hugging Face Login
call :handle_hf_login

echo.
echo =======================================================
echo [SUCCESS] Installation complete!
echo You can now run 'start.bat' to launch ArtTic-LAB.
echo =======================================================
echo.
pause
endlocal