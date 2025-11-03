#!/bin/bash
# ArtTic-LAB Launcher for Linux/macOS

# --- Configuration ---
ENV_NAME="ArtTic-LAB"

# --- Subroutine to find Conda installation ---
find_conda() {
    if command -v conda &> /dev/null; then
        CONDA_BASE_PATH=$(conda info --base)
        return 0
    fi
    local common_paths=(
        "$HOME/miniconda3" "$HOME/anaconda3" "$HOME/miniforge3"
        "/opt/miniconda3" "/opt/anaconda3" "/opt/miniforge3"
    )
    for path in "${common_paths[@]}"; do
        if [ -f "$path/bin/conda" ]; then
            CONDA_BASE_PATH="$path"
            return 0
        fi
    done
    return 1
}

# --- Main Script ---
echo "[INFO] Preparing to launch ArtTic-LAB..."

# 1. Find and Initialize Conda
if ! find_conda; then
    echo "[ERROR] Conda installation not found." >&2
    echo "Please ensure Miniconda, Anaconda, or Miniforge is installed and run install.sh." >&2
    exit 1
fi
echo "[INFO] Conda found at: ${CONDA_BASE_PATH}"

source "${CONDA_BASE_PATH}/etc/profile.d/conda.sh"
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to initialize the Conda command environment." >&2
    echo "Your Conda installation might be corrupted." >&2
    exit 1
fi

# 2. Verify and Activate Environment
echo "[INFO] Checking for '${ENV_NAME}' environment..."
if ! conda env list | grep -q "^${ENV_NAME} "; then
    echo "[ERROR] The '${ENV_NAME}' environment was not found." >&2
    echo "Please run './install.sh' first to set it up." >&2
    exit 1
fi

echo "[INFO] Activating environment..."
conda activate "${ENV_NAME}"
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to activate the '${ENV_NAME}' environment." >&2
    echo "Please try running './install.sh' again." >&2
    exit 1
fi

# 3. Launch the Application
echo "[SUCCESS] Environment activated. Launching application..."
echo
echo "======================================================="
echo "             Launching ArtTic-LAB"
echo "======================================================="
echo

python app.py "$@"

echo
echo "======================================================="
echo "ArtTic-LAB has closed."
echo "======================================================="
echo

exit 0