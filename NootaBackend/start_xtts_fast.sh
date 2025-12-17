#!/bin/bash

# Start XTTS Fast Server

cd "$(dirname "$0")" || exit 1

echo " Killing any existing XTTS processes..."
pkill -f "xtts_server" 2>/dev/null || true
pkill -f "python.*xtts" 2>/dev/null || true
sleep 2

echo ""
echo "Starting XTTS Fast Server (GPU Optimized)..."
echo ""

# Export port
export XTTS_PORT=8000

# Run the fast server
python3.11 xtts_server_fast.py > /tmp/xtts_fast.log 2>&1 &

XTTS_PID=$!
echo " Server started (PID: $XTTS_PID)"
echo ""
echo " Logs:"
echo "   tail -f /tmp/xtts_fast.log"
echo ""
echo "  Health check:"
echo "   curl -s http://localhost:8000/health | jq"
echo ""
echo " Waiting for server to be ready..."
sleep 10

# Check health
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo " Server is ready!"
    curl -s http://localhost:8000/health | jq '.'
else
    echo " Server failed to start. Check logs:"
    tail -20 /tmp/xtts_fast.log
    exit 1
fi
