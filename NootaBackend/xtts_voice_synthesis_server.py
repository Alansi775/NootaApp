#!/usr/bin/env python3
# NootaBackend/xtts_voice_synthesis_server.py

import os
import sys
import torch
import logging
from flask import Flask, request, jsonify, send_file
from TTS.api import TTS
import io

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Check device availability
device = "cuda" if torch.cuda.is_available() else "cpu"
logger.info(f"Using device: {device}")

# Load XTTS v2 model
try:
    logger.info("Loading XTTS v2 model...")
    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=True, gpu=(device == "cuda"))
    logger.info("XTTS v2 model loaded successfully")
except Exception as e:
    logger.error(f"Failed to load XTTS model: {e}")
    sys.exit(1)

# Language code mapping
SUPPORTED_LANGUAGES = {
    "en": "en",
    "ar": "ar",
    "tr": "tr",
    "es": "es",
    "fr": "fr",
    "de": "de",
    "it": "it",
    "pt": "pt",
    "zh": "zh-cn",
    "ja": "ja",
    "ko": "ko"
}

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "healthy",
        "device": device,
        "model": "XTTS v2"
    })

@app.route('/generate', methods=['POST'])
def generate_speech():
    try:
        data = request.get_json()
        
        # Validate input
        if not data or 'text' not in data or 'language' not in data:
            return jsonify({
                "error": "Missing required fields: text, language"
            }), 400
        
        text = data.get('text')
        language = data.get('language', 'en')
        speaker_audio_path = data.get('speaker_audio_path')
        
        # Validate text
        if not text or len(text.strip()) == 0:
            return jsonify({"error": "Text cannot be empty"}), 400
        
        # Validate language
        if language not in SUPPORTED_LANGUAGES:
            return jsonify({
                "error": f"Unsupported language. Supported: {list(SUPPORTED_LANGUAGES.keys())}"
            }), 400
        
        language_code = SUPPORTED_LANGUAGES[language]
        
        logger.info(f"Generating speech for: '{text[:50]}...' in language: {language_code}")
        
        # Generate speech
        try:
            # If speaker audio is provided, use it for voice cloning
            if speaker_audio_path and os.path.exists(speaker_audio_path):
                logger.info(f"Using speaker reference: {speaker_audio_path}")
                output_path = "/tmp/tts_output.wav"
                tts.tts_to_file(
                    text=text,
                    speaker_wav=speaker_audio_path,
                    language=language_code,
                    file_path=output_path
                )
            else:
                # Use default voice if no speaker reference
                logger.warning("No speaker reference provided, using default voice")
                output_path = "/tmp/tts_output.wav"
                tts.tts_to_file(
                    text=text,
                    language=language_code,
                    file_path=output_path
                )
            
            # Read generated audio
            with open(output_path, 'rb') as f:
                audio_data = f.read()
            
            logger.info(f"Speech generated successfully ({len(audio_data)} bytes)")
            
            return send_file(
                io.BytesIO(audio_data),
                mimetype="audio/wav",
                as_attachment=True,
                download_name="synthesis.wav"
            )
        
        except Exception as synthesis_error:
            logger.error(f"Synthesis error: {synthesis_error}")
            return jsonify({
                "error": f"Speech synthesis failed: {str(synthesis_error)}"
            }), 500
    
    except Exception as e:
        logger.error(f"Error in /generate endpoint: {e}")
        return jsonify({
            "error": f"Server error: {str(e)}"
        }), 500

@app.route('/supported-languages', methods=['GET'])
def get_supported_languages():
    return jsonify({
        "supported_languages": list(SUPPORTED_LANGUAGES.keys()),
        "device": device
    })

if __name__ == '__main__':
    port = os.getenv('XTTS_PORT', 8000)
    logger.info(f"Starting XTTS v2 server on port {port}")
    app.run(host='0.0.0.0', port=int(port), debug=False)
