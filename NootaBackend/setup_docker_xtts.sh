#!/bin/bash
# XTTS v2 Docker Setup - Automated

set -e

echo "=========================================================="
echo "🐳 XTTS v2 Docker Setup - Kaggle-Proven Solution"
echo "=========================================================="
echo ""

# Step 1: Check Docker
echo "1️⃣  Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing..."
    brew install --cask docker
fi

# Step 2: Start Docker daemon
echo "  Starting Docker daemon..."
open /Applications/Docker.app 2>/dev/null || true

# Wait for Docker to be ready
DOCKER_READY=0
for i in {1..30}; do
    if docker ps &> /dev/null; then
        DOCKER_READY=1
        break
    fi
    echo "    Waiting for Docker... ($i/30)"
    sleep 2
done

if [ $DOCKER_READY -eq 0 ]; then
    echo "Docker daemon failed to start. Please:"
    echo "   1. Open /Applications/Docker.app manually"
    echo "   2. Wait 1-2 minutes for it to fully load"
    echo "   3. Then run this script again"
    exit 1
fi

echo " Docker is ready!"
echo ""

# Step 3: Pull XTTS v2 image
echo "  Pulling XTTS v2 Docker image (this may take 5-10 minutes)..."
docker pull coqui/xtts-v2

echo ""
echo " Image pulled successfully!"
echo ""

# Step 4: Run XTTS v2 container
echo "4️⃣  Starting XTTS v2 container..."
docker run -d \
  --name xtts-v2-server \
  -p 8000:5000 \
  --memory 4g \
  coqui/xtts-v2

echo " Container started!"
echo ""

# Step 5: Wait for server to be ready
echo "5️⃣  Waiting for XTTS v2 server to initialize (may take 1-2 minutes)..."
XTTS_READY=0
for i in {1..60}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        XTTS_READY=1
        break
    fi
    echo "    Loading model... ($i/60)"
    sleep 2
done

if [ $XTTS_READY -eq 0 ]; then
    echo " Server not responding. Check logs:"
    docker logs xtts-v2-server
    exit 1
fi

echo " XTTS v2 server is ready!"
echo ""

# Step 6: Test health endpoint
echo "6️⃣  Testing XTTS v2 health endpoint..."
HEALTH=$(curl -s http://localhost:8000/health | jq '.status' 2>/dev/null || echo "error")
echo "   Status: $HEALTH"
echo ""

# Step 7: Update .env
echo "7️⃣  Updating backend .env..."
ENV_FILE="/Users/MohammedSaleh/Desktop/SwiftProjects/NootaApp/NootaBackend/.env"

if [ -f "$ENV_FILE" ]; then
    # Comment out or update XTTS settings
    sed -i.bak 's|^XTTS_LOCAL_SERVER=.*|XTTS_LOCAL_SERVER=http://localhost:8000|' "$ENV_FILE" || \
    echo "XTTS_LOCAL_SERVER=http://localhost:8000" >> "$ENV_FILE"
    
    echo " .env updated"
else
    echo " .env not found, but Docker XTTS is running at http://localhost:8000"
fi

echo ""
echo "=========================================================="
echo "XTTS v2 Docker Setup Complete!"
echo "=========================================================="
echo ""
echo " Summary:"
echo "    Docker installed"
echo "    XTTS v2 image pulled"
echo "    Container running (xtts-v2-server)"
echo "    Server responding at http://localhost:8000"
echo ""
echo "Next steps:"
echo "   1. Restart Node.js backend: npm start"
echo "   2. Test voice synthesis"
echo ""
echo "🔗 Server details:"
echo "   - URL: http://localhost:8000"
echo "   - Health check: curl http://localhost:8000/health"
echo "   - Logs: docker logs xtts-v2-server"
echo ""
echo " To manage container:"
echo "   - Stop:  docker stop xtts-v2-server"
echo "   - Start: docker start xtts-v2-server"
echo "   - Remove: docker rm xtts-v2-server"
echo ""
