<#
    .SYNOPSIS
    ArtTic-LAB Modern Installer for Windows
    
    .DESCRIPTION
    Automates the setup of the Conda environment, installs dependencies based on 
    hardware detection, and sets up Node.js requirements.
#>

$Env:ENV_NAME = "ArtTic-LAB"
$Env:PYTHON_VERSION = "3.11"
$ErrorActionPreference = "Stop"

# --- Visual Styling ---
function Write-Header {
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "           ArtTic-LAB Installer for Windows            " -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n[STEP] $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-ErrorLog {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-WarningLog {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Magenta
}

# --- Logic ---

Write-Header

# 1. Find Conda
Write-Step "Searching for Conda Installation"
$PossiblePaths = @(
    "$env:USERPROFILE\miniforge3",
    "$env:USERPROFILE\Miniconda3",
    "$env:USERPROFILE\anaconda3",
    "$env:ProgramData\miniforge3",
    "$env:ProgramData\Miniconda3",
    "$env:ProgramData\anaconda3"
)

$CondaPath = $null
foreach ($path in $PossiblePaths) {
    if (Test-Path "$path\condabin\conda.bat") {
        $CondaPath = "$path\condabin\conda.bat"
        break
    }
}

if (-not $CondaPath) {
    Write-ErrorLog "Could not find Conda. Please ensure Miniconda, Anaconda, or Miniforge is installed."
    Read-Host "Press Enter to exit..."
    exit 1
}

Write-Success "Found Conda at: $CondaPath"

# 2. Environment Management
Write-Step "Environment Configuration"
$EnvExists = & $CondaPath env list | Select-String -Pattern "^$Env:ENV_NAME\s"

if ($EnvExists) {
    Write-WarningLog "Environment '$Env:ENV_NAME' already exists."
    $Choice = Read-Host "Do you want to remove and reinstall it? (y/n)"
    if ($Choice -eq 'y') {
        Write-Info "Removing existing environment..."
        & $CondaPath env remove --name "$Env:ENV_NAME" -y | Out-Null
        Write-Info "Creating new environment..."
        & $CondaPath create --name "$Env:ENV_NAME" python="$Env:PYTHON_VERSION" -y
    } else {
        Write-Info "Skipping creation. Updating existing environment."
    }
} else {
    Write-Info "Creating new environment '$Env:ENV_NAME'..."
    & $CondaPath create --name "$Env:ENV_NAME" python="$Env:PYTHON_VERSION" -y
}

# 3. Install Dependencies
Write-Step "Installing Core Dependencies"
Write-Info "Upgrading pip..."
& $CondaPath run --no-capture-output -n "$Env:ENV_NAME" python -m pip install --upgrade pip --quiet

if (Test-Path "requirements.txt") {
    Write-Info "Installing from requirements.txt..."
    & $CondaPath run --no-capture-output -n "$Env:ENV_NAME" pip install -r requirements.txt
} else {
    Write-ErrorLog "requirements.txt not found!"
    exit 1
}

# 4. Hardware Detection
Write-Step "Hardware Detection & PyTorch Setup"
$DetectScript = @"
from torchruntime.device_db import get_gpus
from torchruntime.platform_detection import get_torch_platform
try:
    print(get_torch_platform(get_gpus()))
except Exception as e:
    print('ERROR')
"@

$DetectFile = "._detect_hw.py"
Set-Content -Path $DetectFile -Value $DetectScript

Write-Info "Running hardware detection..."
$TorchPlatform = & $CondaPath run -n "$Env:ENV_NAME" python $DetectFile
Remove-Item $DetectFile -ErrorAction SilentlyContinue

if ($null -eq $TorchPlatform -or $TorchPlatform -eq 'ERROR') {
    Write-ErrorLog "Failed to detect hardware. Installing default CPU torch."
    $TorchPlatform = "cpu"
} else {
    Write-Success "Detected Platform: $TorchPlatform"
}

Write-Info "Installing PyTorch for $TorchPlatform..."

if ($TorchPlatform -eq "xpu") {
    & $CondaPath run --no-capture-output -n "$Env:ENV_NAME" pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/xpu
    & $CondaPath run --no-capture-output -n "$Env:ENV_NAME" pip install intel-extension-for-pytorch==2.8.10+xpu --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
}
elseif ($TorchPlatform -match "^cu") {
    # CUDA detected
    & $CondaPath run --no-capture-output -n "$Env:ENV_NAME" pip install torch torchvision torchaudio
}
else {
    # CPU or other
    & $CondaPath run --no-capture-output -n "$Env:ENV_NAME" pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    & $CondaPath run --no-capture-output -n "$Env:ENV_NAME" pip install intel-extension-for-pytorch --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/cpu/us/
}

# 5. Web UI
Write-Step "Web UI Dependencies"
if (Get-Command npm -ErrorAction SilentlyContinue) {
    if (Test-Path "web") {
        Push-Location "web"
        Write-Info "Running npm install..."
        npm install | Out-Null
        Pop-Location
        Write-Success "Web UI dependencies installed."
    } else {
        Write-WarningLog "Folder 'web' not found."
    }
} else {
    Write-WarningLog "npm (Node.js) not found. Skipping UI icons installation."
}

# 6. Hugging Face Login
Write-Step "Hugging Face Authentication"
Write-Host "Models like SD3 and FLUX require Hugging Face authentication." -ForegroundColor Gray
$LoginChoice = Read-Host "Would you like to log in now? (y/n)"

if ($LoginChoice -eq 'y') {
    Write-Info "Please provide your User Access Token (Read permissions)."
    Write-Info "Get it here: https://huggingface.co/settings/tokens"
    Write-Host "`nInteractive Login:" -ForegroundColor White
    & $CondaPath run --no-capture-output -n "$Env:ENV_NAME" huggingface-cli login
} else {
    Write-Info "Skipping login. Run 'huggingface-cli login' manually later."
}

# End
Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "           INSTALLATION COMPLETE                       " -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "You can now run 'start.bat' to launch ArtTic-LAB."
Write-Host ""
Read-Host "Press Enter to close..."