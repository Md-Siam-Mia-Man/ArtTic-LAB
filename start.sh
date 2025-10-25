#!/bin/bash
# ArtTic-LAB Launcher for Linux/macOS

# --- Colors for better output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Function to find Conda installation ---
find_conda() {
    # 1. Best case: Conda is already initialized in the shell's PATH
    if command -v conda &> /dev/null; then
        CONDA_BASE_PATH=$(conda info --base)
        return 0
    fi

    # 2. If not in PATH, search common installation locations
    local common_paths=(
        "$HOME/miniconda3"
        "$HOME/anaconda3"
        "$HOME/miniforge3"
        "/opt/miniconda3"
        "/opt/anaconda3"
        "/opt/miniforge3"
    )
    for path in "${common_paths[@]}"; do
        if [ -f "$path/bin/conda" ]; then
            CONDA_BASE_PATH="$path"
            return 0
        fi
    done

    # 3. If nothing is found, return an error
    return 1
}

echo -e "[INFO] Preparing to launch ArtTic-LAB..."

# =======================================================
# 1. FIND AND INITIALIZE CONDA
# =======================================================
if ! find_conda; then
    echo ""
    echo -e "${RED}[ERROR] Conda installation not found.${NC}" >&2
    echo "Please ensure Miniconda, Anaconda, or Miniforge is installed and run install.sh." >&2
    exit 1
fi
echo -e "[INFO] Conda found at: $CONDA_BASE_PATH"

# Source the Conda initialization script to make 'conda' command available
source "${CONDA_BASE_PATH}/etc/profile.d/conda.sh"
if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}[ERROR] Failed to initialize the Conda command environment.${NC}" >&2
    echo "Your Conda installation might be corrupted." >&2
    exit 1
fi

# =======================================================
# 2. VERIFY AND ACTIVATE ENVIRONMENT
# =======================================================
echo -e "[INFO] Checking for 'ArtTic-LAB' environment..."
if ! conda env list | grep -q "^ArtTic-LAB "; then
    echo ""
    echo -e "${RED}[ERROR] The 'ArtTic-LAB' environment was not found.${NC}" >&2
    echo "Please run the './install.sh' script first to set it up." >&2
    exit 1
fi

echo -e "[INFO] Activating environment..."
conda activate ArtTic-LAB
if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}[ERROR] Failed to activate the 'ArtTic-LAB' environment.${NC}" >&2
    echo "The environment may be corrupted. Please try running './install.sh' again." >&2
    exit 1
fi

# =======================================================
# 3. LAUNCH THE APPLICATION
# =======================================================
echo -e "${GREEN}[SUCCESS] Environment activated. Launching application...${NC}"
echo ""
echo "======================================================="
echo "             Launching ArtTic-LAB"
echo "======================================================="
echo ""

# The "$@" ensures all command-line arguments (e.g., --ui gradio) are passed to the Python script
python app.py "$@"

echo ""
echo "======================================================="
echo "ArtTic-LAB has closed."
echo "======================================================="
echo ""

exit 0