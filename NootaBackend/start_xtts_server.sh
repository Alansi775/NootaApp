#!/bin/bash
# Start XTTS v2 Server - Python 3.11

echo "  Starting XTTS v2 Server"
echo "============================"
echo ""

# Check Python 3.11
if ! command -v python3.11 &> /dev/null; then
    echo "Python 3.11 not found"
    echo "Install: brew install python@3.11"
    exit 1
fi

echo " Python 3.11 found"
echo ""

# Check dependencies
echo "Checking dependencies..."
python3.11 -c "import torch; import TTS; import flask" 2>&1 | grep -q "ModuleNotFoundError" && {
    echo "Missing dependencies"
    echo "Install:"
    echo "  pip3.11 install torch torchvision torchaudio"
    echo "  pip3.11 install TTS flask flask-cors"
    exit 1
}

echo " All dependencies installed"
echo ""

# Start server
cd /Users/MohammedSaleh/Desktop/SwiftProjects/NootaApp/NootaBackend

export XTTS_PORT=8000
echo "Starting server on port 8000..."
echo ""

python3.11 xtts_server_simple.py
