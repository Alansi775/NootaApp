#!/usr/bin/env python3
"""
XTTS v2 Simple HTTP Server - No Dependencies Hell
Works with Python 3.11+ installed locally
"""

import os
import sys
import json
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main():
    print("\n" + "="*60)
    print("  XTTS v2 Setup Check")
    print("="*60 + "\n")
    
    # Check Python version
    py_version = sys.version_info
    print(f"Python Version: {py_version.major}.{py_version.minor}.{py_version.micro}")
    
    if py_version.major < 3 or (py_version.major == 3 and py_version.minor < 11):
        print("Need Python 3.11+")
        print("\n💡 Solution: Install Python 3.11")
        print("   brew install python@3.11")
        return 1
    
    print(" Python version OK\n")
    
    # Check for TTS library
    try:
        import TTS
        print(" TTS library installed")
        print(f"   Version: {TTS.__version__ if hasattr(TTS, '__version__') else 'unknown'}\n")
    except ImportError:
        print("TTS library not installed")
        print("\n💡 Install with:")
        print("   python3.11 -m pip install TTS torch torchvision torchaudio")
        print("   python3.11 -m pip install flask flask-cors")
        return 1
    
    # Check for torch
    try:
        import torch
        print(f" PyTorch installed (v{torch.__version__})")
        print(f"   CUDA available: {torch.cuda.is_available()}\n")
    except ImportError:
        print("PyTorch not installed\n")
        return 1
    
    # Try loading model
    print("Attempting to load XTTS v2 model...")
    print("(This will download ~2GB on first run)\n")
    
    try:
        from TTS.api import TTS
        device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"Device: {device}")
        
        tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", gpu=(device == "cuda"))
        print("\n XTTS v2 model loaded successfully!")
        print("\n" + "="*60)
        print("Everything ready! You can now use XTTS v2")
        print("="*60 + "\n")
        return 0
        
    except Exception as e:
        print(f"\nError loading model: {e}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
