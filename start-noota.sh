#!/bin/bash

# Noota Voice Synthesis - One-Click Startup
# Run this script once to start everything

set -e

PROJECT_DIR="/Users/MohammedSaleh/Desktop/SwiftProjects/NootaApp"
BACKEND_DIR="$PROJECT_DIR/NootaBackend"

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   NOOTA VOICE SYNTHESIS STARTUP      ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if already running
echo " Checking for existing processes..."
XTTS_PID=$(pgrep -f "xtts_server_simple.py" || echo "")
BACKEND_PID=$(pgrep -f "npm start" || echo "")

if [ ! -z "$XTTS_PID" ]; then
    echo " XTTS server already running (PID: $XTTS_PID)"
else
    echo " Starting XTTS v2 server..."
    cd "$BACKEND_DIR"
    (echo "y" | nohup python3.11 xtts_server_simple.py > /tmp/xtts_server.log 2>&1) &
    XTTS_PID=$!
    echo " XTTS server started (PID: $XTTS_PID)"
    echo ""
    echo " Waiting for model to load (30 seconds)..."
    sleep 30
    echo " XTTS ready!"
    echo ""
fi

if [ ! -z "$BACKEND_PID" ]; then
    echo " Backend already running (PID: $BACKEND_PID)"
    echo "ℹ️  Skipping backend restart"
else
    echo " Starting Node.js backend..."
    cd "$BACKEND_DIR"
    npm start &
    BACKEND_PID=$!
    echo " Backend started (PID: $BACKEND_PID)"
    echo ""
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  SYSTEM READY                        ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "🌐 Services Running:"
echo "   • XTTS v2 Server:    http://localhost:8000"
echo "   • Backend Server:    http://localhost:5001"
echo ""
echo "📱 Next Step:"
echo "   1. Open Xcode"
echo "   2. Product → Run (⌘R)"
echo "   3. Select iPhone Simulator"
echo ""
echo " Logs:"
echo "   • XTTS:   tail -f /tmp/xtts_server.log"
echo "   • Backend: (shown in this terminal)"
echo ""
