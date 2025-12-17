#!/usr/bin/env python3.11
"""
XTTS v2 Flask Server - Auto-License Edition
Bypasses interactive license prompt completely
"""

import os
import sys
import json
import logging
import io
from pathlib import Path

# Set environment variables BEFORE importing TTS
os.environ['TTS_HOME'] = '/tmp/tts_models'
os.environ['PYTHONUNBUFFERED'] = '1'
os.makedirs(os.environ['TTS_HOME'], exist_ok=True)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

print("\n" + "="*60)
print("  XTTS v2 Flask Server")
print("="*60 + "\n")

print("1. Importing libraries...")
try:
    import torch
    from flask import Flask, request, jsonify, send_file
    from flask_cors import CORS
    print("    Flask & Torch imported")
except Exception as e:
    print(f"   Error: {e}")
    sys.exit(1)

# Patch TTS to skip license prompt
print("2. Patching TTS license check...")
import sys
from io import StringIO

class LicenseBypassInput:
    def __call__(self, prompt=""):
        print(f"   🔓 Auto-confirming license...")
        return "y"

sys.modules['builtins'].input = LicenseBypassInput()

print("    License check patched")

print("3. Loading XTTS model...")
try:
    from TTS.api import TTS
    
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"   🖥️  Device: {device}")
    
    # Torch patch for weights_only compatibility
    torch.serialization.safe_load = lambda *args, **kwargs: torch.load(*args, **kwargs, weights_only=False)
    
    # Load model
    print("    Downloading model (first time: 2-5 minutes)...")
    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=True, gpu=(device=="cuda"))
    tts = tts.to(device)
    
    print("    Model loaded successfully!")
    MODEL_READY = True
    
except Exception as e:
    print(f"   Error loading model: {e}")
    import traceback
    traceback.print_exc()
    MODEL_READY = False

# Flask app
app = Flask(__name__)
CORS(app)

print("\n" + "="*60)
print("🌐 API Endpoints Ready")
print("="*60 + "\n")

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'ready' if MODEL_READY else 'loading',
        'model': 'xtts_v2',
        'device': 'cuda' if torch.cuda.is_available() else 'cpu'
    })

@app.route('/api/synthesize', methods=['POST'])
def synthesize():
    """Synthesize speech from text with optional voice cloning"""
    
    if not MODEL_READY:
        return jsonify({'error': 'Model still loading'}), 503
    
    try:
        # Get data from JSON or form
        if request.is_json:
            data = request.get_json()
        else:
            data = request.form.to_dict()
        
        text = data.get('text', '')
        language = data.get('language', 'en')
        speaker_wav = None
        
        if not text:
            return jsonify({'error': 'Text is required'}), 400
        
        logger.info(f"🎤 Synthesizing: [{language}] {text[:50]}...")
        
        # Handle speaker WAV file for voice cloning
        if 'speaker_wav' in request.files:
            wav_file = request.files['speaker_wav']
            speaker_wav = f"/tmp/speaker_{os.urandom(4).hex()}.wav"
            wav_file.save(speaker_wav)
            logger.info(f"📢 Using voice profile for cloning")
        
        # Generate audio
        output_path = f"/tmp/output_{os.urandom(4).hex()}.wav"
        
        tts.tts_to_file(
            text=text,
            speaker_wav=speaker_wav,
            language=language,
            file_path=output_path
        )
        
        # Read output
        with open(output_path, 'rb') as f:
            audio_data = f.read()
        
        # Cleanup
        try:
            os.remove(output_path)
            if speaker_wav and os.path.exists(speaker_wav):
                os.remove(speaker_wav)
        except:
            pass
        
        logger.info(f" Generated {len(audio_data)} bytes audio")
        
        return send_file(
            io.BytesIO(audio_data),
            mimetype='audio/wav',
            as_attachment=True,
            download_name='output.wav'
        )
    
    except Exception as e:
        logger.error(f"Synthesis error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

# Run server
if __name__ == '__main__':
    port = int(os.getenv('XTTS_PORT', 8000))
    
    print(f"Server Starting!")
    print(f"   🌐 http://localhost:{port}")
    print(f"   💚 Health: http://localhost:{port}/health")
    print(f"     API: POST http://localhost:{port}/api/synthesize")
    print("\n" + "="*60 + "\n")
    
    app.run(host='0.0.0.0', port=port, debug=False, threaded=True, use_reloader=False)
