#!/bin/bash
# XTTS v2 Installation Script - Based on Kaggle working code

set -e

echo "============================================================"
echo "XTTS v2 Setup - Using Kaggle-proven method"
echo "============================================================"

# Get Python venv path
VENV_PATH="${1:-.}/xtts_env"

echo ""
echo "📦 Python Virtual Environment: $VENV_PATH"

# Create venv if doesn't exist
if [ ! -d "$VENV_PATH" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$VENV_PATH"
fi

# Activate venv
source "$VENV_PATH/bin/activate"

echo ""
echo "🐍 Python Version:"
python --version

echo ""
echo " Installing XTTS v2 dependencies (Kaggle-proven versions)..."
echo ""

# Remove old versions first (like in Kaggle)
echo "Removing old PyTorch versions..."
pip uninstall -y torch torchvision torchaudio 2>/dev/null || true

# Install PyTorch 2.1 (the EXACT version from Kaggle that works)
echo "Installing PyTorch 2.1 (CPU-optimized)..."
pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cpu

# Install TTS and other dependencies
echo "Installing TTS library and dependencies..."
pip install TTS==0.21.1 numpy==1.26.0 transformers==4.38.2

# Install Flask for server
echo "Installing Flask server dependencies..."
pip install flask flask-cors python-dotenv

# Install pydub for audio processing (optional but recommended)
echo "Installing audio processing tools..."
pip install pydub

echo ""
echo " Installation complete!"
echo ""
echo " Next steps:"
echo "   1. Activate venv: source $VENV_PATH/bin/activate"
echo "   2. Run server: python xtts_working_server.py"
echo "   3. Test health: curl http://localhost:8000/health"
echo ""
echo "🔗 Server endpoint: http://localhost:8000/generate"
echo ""
