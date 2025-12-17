#!/usr/bin/env python3.11
"""
XTTS v2 Simple Flask Server
Based on Kaggle working code - pure Python solution
"""

import os
import sys
import json
import logging
from pathlib import Path

# Auto-agree to XTTS license (non-commercial CPML)
os.environ['TTS_HOME'] = '/tmp/tts_model_cache'
os.makedirs(os.environ['TTS_HOME'], exist_ok=True)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

print("\n" + "="*60)
print("  XTTS v2 Server Starting...")
print("="*60 + "\n")

try:
    print("1. Importing libraries...")
    import torch
    from TTS.api import TTS
    from flask import Flask, request, jsonify, send_file
    from flask_cors import CORS
    import io
    print("    All imports successful\n")
except ImportError as e:
    print(f"   Import error: {e}")
    print("\n   Install dependencies:")
    print("   pip3.11 install torch torchvision torchaudio TTS flask flask-cors")
    sys.exit(1)

# Initialize Flask
app = Flask(__name__)
CORS(app)

# Initialize XTTS model
print("2. Loading XTTS v2 model...")
print("    First time takes 2-5 minutes...\n")

device = "cuda" if torch.cuda.is_available() else "cpu"
logger.info(f"🖥️  Using device: {device}")

try:
    # This is the EXACT code from your Kaggle notebook
    torch.serialization.safe_load = lambda *args, **kwargs: torch.load(*args, **kwargs, weights_only=False)
    
    # Auto-agree to license prompt by setting environment variable
    os.environ['TTS_PLUGINS'] = '/tmp/.tts_plugins'
    
    # Load model
    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=True, gpu=torch.cuda.is_available()).to(device)
    
    logger.info(" XTTS v2 model loaded successfully!")
    TTS_READY = True
except Exception as e:
    logger.error(f"Failed to load model: {e}")
    TTS_READY = False

print("\n" + "="*60)
print("🌐 Flask API Endpoints")
print("="*60 + "\n")

# Endpoints
@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ready' if TTS_READY else 'error', 'model': 'xtts_v2'})

@app.route('/api/synthesize', methods=['POST'])
def synthesize():
    """Synthesize speech - supports both JSON and multipart/form-data"""
    
    if not TTS_READY:
        return jsonify({'error': 'Model not ready'}), 503
    
    try:
        # Support both JSON and form data - don't error on Content-Type
        data = {}
        if request.is_json:
            data = request.get_json() or {}
        if request.form:
            data.update(request.form.to_dict())
        
        text = data.get('text', '')
        language = data.get('language', 'en')
        speaker_wav = None
        
        if not text:
            return jsonify({'error': 'No text'}), 400
        
        logger.info(f"🎤 Synthesizing: {language} - {text[:50]}...")
        
        # Handle speaker WAV for voice cloning
        if 'speaker_wav' in request.files:
            wav_file = request.files['speaker_wav']
            speaker_wav = f"/tmp/{wav_file.filename}"
            wav_file.save(speaker_wav)
            logger.info(f"📢 Using reference voice for cloning")
        
        # Generate speech (exactly like Kaggle)
        output_path = f"/tmp/tts_output_{os.urandom(4).hex()}.wav"
        
        tts.tts_to_file(
            text=text,
            speaker_wav=speaker_wav,
            language=language,
            file_path=output_path
        )
        
        # Read and return
        with open(output_path, 'rb') as f:
            audio_data = f.read()
        
        # Cleanup
        try:
            os.remove(output_path)
            if speaker_wav and os.path.exists(speaker_wav):
                os.remove(speaker_wav)
        except:
            pass
        
        logger.info(f" Generated {len(audio_data)} bytes")
        
        return send_file(
            io.BytesIO(audio_data),
            mimetype='audio/wav',
            as_attachment=True,
            download_name='output.wav'
        )
    
    except Exception as e:
        logger.error(f"Error: {e}")
        return jsonify({'error': str(e)}), 500

# Run server
if __name__ == '__main__':
    port = int(os.getenv('XTTS_PORT', 8000))
    
    print(f"Server ready!")
    print(f"   URL: http://localhost:{port}")
    print(f"   Health: http://localhost:{port}/health")
    print(f"   API: POST http://localhost:{port}/api/synthesize")
    print("\n" + "="*60 + "\n")
    
    app.run(host='0.0.0.0', port=port, debug=False, threaded=True)
