#!/bin/bash
# Quick XTTS v2 Docker Setup (Custom Image - Kaggle-proven code)

set -e

echo "🐳 XTTS v2 Docker Setup"
echo "========================"
echo ""

# Check if docker is running
if ! docker ps &> /dev/null; then
    echo "Docker daemon not running"
    echo " Start Docker: open /Applications/Docker.app"
    echo " Wait 1-2 minutes, then run this script again"
    exit 1
fi

echo " Docker is running"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 1. Build custom image
echo "1. Building custom XTTS v2 image (based on Kaggle code)..."
echo "    First time takes 5-10 minutes..."

cd "$SCRIPT_DIR"

if docker image inspect noota-xtts-v2:latest &> /dev/null; then
    echo "    Image already exists"
else
    docker build -t noota-xtts-v2:latest -f Dockerfile .
    echo "    Image built successfully"
fi

echo ""

# 2. Stop existing container if running
if docker ps --filter name=xtts-v2-server --quiet | grep -q .; then
    echo "2. Stopping existing container..."
    docker stop xtts-v2-server
    docker rm xtts-v2-server 2>/dev/null || true
    echo "    Stopped"
fi

echo ""

# 3. Run container
echo "3. Starting XTTS v2 container..."
docker run -d \
  --name xtts-v2-server \
  -p 8000:5000 \
  --memory 4g \
  noota-xtts-v2:latest

CONTAINER_ID=$(docker ps --filter name=xtts-v2-server --format '{{.ID}}' | head -c 12)
echo "    Container started (ID: $CONTAINER_ID)"
echo ""

# 4. Show next steps
echo "4. Waiting for server to initialize..."
echo ""
echo " This may take 2-5 minutes on first run"
echo ""
echo " Watch progress in a new terminal:"
echo "   $ docker logs -f xtts-v2-server"
echo ""
echo "🔗 Test health when ready:"
echo "   $ curl http://localhost:8000/health"
echo ""
echo " Setup complete! Server should be ready in 2-5 minutes."
echo ""
