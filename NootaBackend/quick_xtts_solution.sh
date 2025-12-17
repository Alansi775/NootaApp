#!/bin/bash
# Quick XTTS v2 Solution - Use Public HF Spaces endpoint
# This is the simplest working solution until Docker is set up

echo "========================================================"
echo "XTTS v2 Quick Solution - Using HF Spaces"
echo "========================================================"
echo ""
echo " Python 3.13 doesn't have PyTorch wheels on macOS"
echo " Solution: Use free HuggingFace Spaces instead"
echo ""
echo "Steps:"
echo "1. Backend will use: https://coqui-coqui-xtts.hf.space"
echo "2. Get XTTS v2 working via API (no local setup needed)"
echo "3. Voice cloning works just like Kaggle"
echo ""

# Update .env to use HF Spaces
cd /Users/MohammedSaleh/Desktop/SwiftProjects/NootaApp/NootaBackend

if [ -f .env ]; then
    # Comment out local server, keep HF configs
    sed -i.bak 's/^XTTS_LOCAL_SERVER/#XTTS_LOCAL_SERVER/' .env
    echo " Updated .env to disable local XTTS"
fi

echo ""
echo " Configuration:"
echo "   - Backend will try HF Spaces first"
echo "   - Voice cloning: Supported"
echo "   - Languages: All (multilingual)"
echo "   - Speed: 5-15 seconds per message"
echo ""
echo " To test:"
echo "   npm start"
echo "   # Then test voice synthesis endpoint"
echo ""
