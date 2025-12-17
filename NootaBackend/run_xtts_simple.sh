#!/bin/bash
# Simple XTTS v2 Docker Run (using official image)

set -e

echo "🐳 XTTS v2 Docker Setup (Official Image)"
echo "========================================="
echo ""

# Wait for Docker
echo "Waiting for Docker daemon..."
for i in {1..30}; do
    if docker ps &> /dev/null; then
        echo " Docker is ready"
        break
    fi
    echo "    Waiting... ($i/30)"
    sleep 1
done

echo ""

# Pull official image
echo "1. Pulling official XTTS v2 image..."
echo "    This may take 5-10 minutes on first run..."
docker pull ghcr.io/coqui-ai/xtts-v2

echo ""
echo " Image pulled!"
echo ""

# Stop any existing container
if docker ps -a | grep -q xtts-v2-server; then
    echo "2. Cleaning up existing container..."
    docker stop xtts-v2-server 2>/dev/null || true
    docker rm xtts-v2-server 2>/dev/null || true
    echo "    Cleaned"
    echo ""
fi

# Run container
echo "3. Starting XTTS v2 server..."
docker run -d \
  --name xtts-v2-server \
  -p 8000:80 \
  --memory 4g \
  ghcr.io/coqui-ai/xtts-v2

echo "    Container started"
echo ""

# Wait for server
echo "4. Waiting for server to be ready (2-5 minutes)..."
sleep 30

for i in {1..60}; do
    if curl -s http://localhost:8000 > /dev/null 2>&1; then
        echo "    Server is ready!"
        break
    fi
    if [ $((i % 10)) -eq 0 ]; then
        echo "    Loading... ($i/60)"
    fi
    sleep 2
done

echo ""
echo "========================================="
echo " XTTS v2 Server Ready!"
echo "========================================="
echo ""
echo "📍 Server: http://localhost:8000"
echo ""
echo " Watch logs:"
echo "   docker logs -f xtts-v2-server"
echo ""
echo "🔗 Test endpoint:"
echo "   curl http://localhost:8000"
echo ""
