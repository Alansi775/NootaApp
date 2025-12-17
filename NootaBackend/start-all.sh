#!/bin/bash

# Noota Complete System Startup Script
# Starts XTTS v2 Server + Node.js Backend in parallel with logging

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR"
LOGS_DIR="$SCRIPT_DIR/logs"
XTTS_LOG="$LOGS_DIR/xtts_server.log"
BACKEND_LOG="$LOGS_DIR/backend_server.log"

#  Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

#  Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        Noota System Startup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

#  Kill any existing processes on ports 8000 and 5001
echo -e "${YELLOW} Checking for existing processes...${NC}"
pkill -f "xtts_server_simple.py" 2>/dev/null || true
pkill -f "node src/index.js" 2>/dev/null || true
sleep 2

# 🐍 Start XTTS v2 Server
echo -e "${YELLOW}📦 Starting XTTS v2 Server...${NC}"
cd "$BACKEND_DIR"

# Activate virtual environment and start XTTS
(
    source xtts_env/bin/activate
    
    # Verify dependencies
    python3 -c "import torch; print(f' torch: {torch.__version__}')"
    python3 -c "import transformers; print(f' transformers loaded')"
    python3 -c "import TTS; print(f' TTS library loaded')"
    
    echo ""
    echo -e "${GREEN}🔊 Launching XTTS v2 Server on port 8000...${NC}"
    python3 xtts_server_simple.py > "$XTTS_LOG" 2>&1 &
    XTTS_PID=$!
    echo "XTTS PID: $XTTS_PID"
) &
XTTS_SETUP_PID=$!

# Wait for XTTS to start (max 120 seconds for model loading)
echo -e "${YELLOW} Waiting for XTTS to initialize (this may take 1-2 minutes on first run)...${NC}"
XTTS_READY=false
for i in {1..240}; do
    if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        echo -e "${GREEN} XTTS Server is ready!${NC}"
        XTTS_READY=true
        break
    fi
    if [ $i -eq 240 ]; then
        echo -e "${RED}XTTS Server failed to start after 120 seconds${NC}"
        echo "Check logs: $XTTS_LOG"
        if [ -f "$XTTS_LOG" ]; then
            echo "--- Last 50 lines of XTTS log ---"
            tail -50 "$XTTS_LOG"
        fi
        exit 1
    fi
    # Show progress
    if [ $((i % 10)) -eq 0 ]; then
        echo -ne "."
    fi
    sleep 0.5
done

if [ "$XTTS_READY" = false ]; then
    echo -e "${RED}XTTS Server failed to start${NC}"
    exit 1
fi

# 🟢 Start Node.js Backend
echo -e "${YELLOW}📡 Starting Node.js Backend Server...${NC}"
cd "$BACKEND_DIR"
echo -e "${GREEN}Launching Backend on port 5001...${NC}"
npm start > "$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!
echo "Backend PID: $BACKEND_PID"

# Wait for Backend to start
echo -e "${YELLOW} Waiting for Backend to initialize...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:5001/api/health >/dev/null 2>&1; then
        echo -e "${GREEN} Backend Server is ready!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${YELLOW}Backend still initializing...${NC}"
        break
    fi
    echo -ne "."
    sleep 1
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN} SYSTEM READY!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Services Running:${NC}"
echo -e "  🔊 XTTS v2 Server:     ${GREEN}http://localhost:8000${NC}"
echo -e "  📡 Backend Server:     ${GREEN}http://localhost:5001${NC}"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo -e "  XTTS:  $XTTS_LOG"
echo -e "  Backend: $BACKEND_LOG"
echo ""
echo -e "${YELLOW}To stop servers, press Ctrl+C${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW} Stopping servers...${NC}"
    kill $BACKEND_PID 2>/dev/null || true
    kill $XTTS_PID 2>/dev/null || true
    echo -e "${GREEN} Servers stopped${NC}"
}

# Set up trap to cleanup on exit
trap cleanup EXIT INT TERM

# Keep the script running
wait

