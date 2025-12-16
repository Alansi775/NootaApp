#!/bin/bash

# Noota Backend Complete Setup Script
# This script sets up both Node.js Backend and Python XTTS server

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Noota Backend Complete Setup                               ║"
echo "║     XTTS v2 + Node.js + Firebase Integration                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed"
    echo "📥 Download from https://nodejs.org/"
    exit 1
fi

echo "✅ Node.js $(node --version) detected"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed"
    echo "📥 Download from https://www.python.org/"
    exit 1
fi

echo "✅ Python $(python3 --version) detected"

# Step 1: Setup Node.js Backend
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Setting up Node.js Backend"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Install Node dependencies
echo "📦 Installing Node.js dependencies..."
npm install

if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo ""
    echo "⚠️  IMPORTANT: Edit .env file with your Firebase and Google Cloud credentials"
    echo "   Locations:"
    echo "   - FIREBASE_PROJECT_ID: Firebase Console > Project Settings"
    echo "   - FIREBASE_PRIVATE_KEY: Firebase Console > Service Account Key"
    echo "   - GOOGLE_CLOUD_API_KEY: Google Cloud Console > APIs > Translation"
    echo ""
fi

echo "✅ Node.js Backend setup complete"

# Step 2: Setup Python XTTS Server
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Setting up Python XTTS v2 Server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create Python virtual environment
if [ ! -d "xtts_env" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv xtts_env
    echo "✅ Virtual environment created"
fi

# Activate virtual environment
source xtts_env/bin/activate

# Install Python dependencies
echo "📦 Installing Python dependencies..."
echo "   (This may take a few minutes)"
pip install --upgrade pip
pip install TTS torch flask flask-cors python-dotenv

echo "✅ Python dependencies installed"

# Deactivate virtual environment
deactivate

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 Next Steps:"
echo ""
echo "1️⃣  Configure Firebase and Google Cloud credentials:"
echo "   nano .env"
echo ""
echo "2️⃣  In one terminal, start the XTTS v2 server:"
echo "   source xtts_env/bin/activate"
echo "   python xtts_server.py"
echo ""
echo "3️⃣  In another terminal, start the Node.js Backend:"
echo "   npm start           # Production mode"
echo "   npm run dev         # Development mode with auto-reload"
echo ""
echo "4️⃣  Test the setup:"
echo "   curl http://localhost:5000/api/health"
echo "   curl http://localhost:8000/health"
echo ""
echo "📡 Servers will run on:"
echo "   - Node.js Backend: http://localhost:5000"
echo "   - XTTS v2 Server:  http://localhost:8000"
echo ""
echo "📚 For more information, see README.md"
echo ""
