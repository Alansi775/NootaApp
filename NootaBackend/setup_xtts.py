#!/usr/bin/env python3
"""
XTTS v2 Server Setup Guide
Install and run the XTTS v2 Python server
"""

import subprocess
import sys
import os

def install_requirements():
    """Install Python dependencies"""
    print("📦 Installing Python dependencies...")
    
    requirements = [
        "TTS",
        "torch",
        "flask",
        "flask-cors",
        "python-dotenv"
    ]
    
    for package in requirements:
        print(f"  Installing {package}...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
    
    print("✅ All dependencies installed")

def main():
    """Main setup function"""
    print("""
╔════════════════════════════════════════════════════════════════╗
║           Noota XTTS v2 Server Setup                           ║
║     Advanced Voice Cloning Text-to-Speech Server               ║
╚════════════════════════════════════════════════════════════════╝
    """)
    
    # Check Python version
    if sys.version_info < (3, 8):
        print("❌ Python 3.8+ required")
        sys.exit(1)
    
    print(f"✅ Python {sys.version_info.major}.{sys.version_info.minor} detected")
    
    # Install dependencies
    try:
        install_requirements()
    except subprocess.CalledProcessError as e:
        print(f"❌ Installation failed: {e}")
        sys.exit(1)
    
    print("""
✅ Setup complete!

🚀 To start the XTTS v2 server:

    python xtts_server.py

The server will be available at http://localhost:8000

📍 Endpoints:
  - GET  /health              - Server health check
  - GET  /api/languages       - Supported languages
  - GET  /api/model/info      - Model information
  - POST /api/tts             - Generate speech
  - POST /api/tts/batch       - Batch speech generation

💡 Note:
  - First run will download the XTTS v2 model (~2GB)
  - GPU (CUDA) recommended for faster inference
  - Each TTS request takes 3-5 seconds on GPU, ~10-30s on CPU
    """)

if __name__ == "__main__":
    main()
