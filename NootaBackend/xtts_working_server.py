#!/usr/bin/env python3
"""
XTTS v2 Working Server - Based on Kaggle working code
Provides HTTP interface for XTTS v2 voice synthesis with voice cloning
"""

import os
import sys
import json
import torch
import logging
from pathlib import Path
from flask import Flask, request, send_file, jsonify
from flask_cors import CORS
import io

# ============================================================================
# 1. CRITICAL FIXES FOR XTTS v2 (من كود Kaggle بتاعك اللي اشتغل)
# ============================================================================

# Fix PyTorch UnpicklingError (هذي كانت المشكلة!)
torch.serialization.safe_load = lambda *args, **kwargs: torch.load(*args, **kwargs, weights_only=False)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============================================================================
# 2. SETUP FLASK APP
# ============================================================================

app = Flask(__name__)
CORS(app)

# ============================================================================
# 3. INITIALIZE XTTS v2 MODEL
# ============================================================================

device = "cuda" if torch.cuda.is_available() else "cpu"
logger.info(f"🖥️  Using device: {device}")

try:
    logger.info("جاري تحميل نموذج XTTS V2...")
    logger.info("Loading XTTS v2 model (this will take a moment)...")
    
    from TTS.api import TTS
    
    # Load exactly like Kaggle works
    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=True).to(device)
    
    logger.info(" انتهى تحميل نموذج XTTS V2 بنجاح!")
    logger.info(" XTTS v2 model loaded successfully!")
    TTS_MODEL = tts
    TTS_READY = True
    
except Exception as e:
    logger.error(f"Failed to load XTTS model: {e}")
    logger.error(f"خطأ في تحميل النموذج: {e}")
    TTS_MODEL = None
    TTS_READY = False

# ============================================================================
# 4. ENDPOINTS
# ============================================================================

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy' if TTS_READY else 'error',
        'model': 'XTTS v2',
        'device': device,
        'cuda_available': torch.cuda.is_available(),
        'message': 'XTTS v2 Ready' if TTS_READY else 'Model not loaded'
    })

@app.route('/generate', methods=['POST'])
def generate_speech():
    """
    Generate speech using XTTS v2
    
    Request JSON:
    {
        "text": "النص للتوليد",
        "language": "ar",  # Language code
        "speaker_wav": "base64_encoded_audio_or_file_path"  # Optional - for voice cloning
    }
    
    Returns: WAV audio file
    """
    
    if not TTS_READY:
        return jsonify({'error': 'XTTS model not ready'}), 503
    
    try:
        # Get request data
        if request.is_json:
            data = request.get_json()
        else:
            data = request.form.to_dict()
        
        text = data.get('text', '')
        language = data.get('language', 'en')
        speaker_wav_path = None
        
        if not text:
            return jsonify({'error': 'No text provided'}), 400
        
        logger.info(f"🎤 Generating speech for language: {language}")
        logger.info(f" Text: {text[:50]}...")
        
        # Handle speaker_wav (voice cloning reference)
        if 'speaker_wav' in request.files:
            # File uploaded
            wav_file = request.files['speaker_wav']
            speaker_wav_path = f"/tmp/{wav_file.filename}"
            wav_file.save(speaker_wav_path)
            logger.info(f"📢 Using reference voice for cloning: {speaker_wav_path}")
        elif 'speaker_wav' in data and data['speaker_wav']:
            # Path provided
            speaker_wav_path = data['speaker_wav']
            if os.path.exists(speaker_wav_path):
                logger.info(f"📢 Using reference voice: {speaker_wav_path}")
            else:
                logger.warn(f" Reference voice file not found: {speaker_wav_path}")
                speaker_wav_path = None
        
        # Generate speech using XTTS (exactly like Kaggle code)
        logger.info(f"🔊 Calling XTTS v2 for {language}...")
        
        output_path = f"/tmp/tts_output_{os.urandom(4).hex()}.wav"
        
        # Call tts_to_file exactly like Kaggle
        TTS_MODEL.tts_to_file(
            text=text,
            speaker_wav=speaker_wav_path,  # Can be None for default voice
            language=language,
            file_path=output_path
        )
        
        # Read the generated file
        if not os.path.exists(output_path):
            return jsonify({'error': 'Failed to generate audio'}), 500
        
        with open(output_path, 'rb') as f:
            audio_data = f.read()
        
        # Cleanup
        try:
            os.remove(output_path)
            if speaker_wav_path and speaker_wav_path.startswith('/tmp/'):
                os.remove(speaker_wav_path)
        except:
            pass
        
        logger.info(f" Speech generated successfully ({len(audio_data)} bytes)")
        
        # Return audio file
        return send_file(
            io.BytesIO(audio_data),
            mimetype='audio/wav',
            as_attachment=True,
            download_name='output.wav'
        )
    
    except Exception as e:
        logger.error(f"Error during speech generation: {str(e)}")
        logger.error(f"خطأ في توليد الصوت: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/predict', methods=['POST'])
def api_predict():
    """
    Gradio-compatible endpoint for HF Spaces compatibility
    """
    return generate_speech()

# ============================================================================
# 5. RUN SERVER
# ============================================================================

if __name__ == '__main__':
    port = int(os.getenv('XTTS_PORT', 8000))
    
    logger.info("\n" + "="*60)
    logger.info("Starting XTTS v2 Server...")
    logger.info(f"🌐 Server running at: http://localhost:{port}")
    logger.info(f"🖥️  Device: {device}")
    logger.info(f" Model Status: {'Ready' if TTS_READY else 'Error'}")
    logger.info("="*60 + "\n")
    
    app.run(host='0.0.0.0', port=port, debug=False, threaded=True)
