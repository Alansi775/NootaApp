"""
Noota XTTS v2 Server
Python backend for text-to-speech with voice cloning using XTTS v2 model

Install requirements:
pip install TTS torch flask flask-cors python-dotenv
"""

import os
import io
import torch
import logging
from flask import Flask, request, send_file, jsonify
from flask_cors import CORS
from TTS.api import TTS
from dotenv import load_dotenv

load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Initialize XTTS model
device = "cuda" if torch.cuda.is_available() else "cpu"
logger.info(f"Using device: {device}")
logger.info("Loading XTTS v2 model (this may take a minute on first run)...")

try:
    tts = TTS("tts_models/multilingual/multi_speaker/xtts_v2", gpu=(device == "cuda"))
    logger.info("✅ XTTS v2 model loaded successfully")
except Exception as e:
    logger.error(f"❌ Failed to load XTTS model: {e}")
    tts = None

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'model': 'XTTS v2',
        'device': device,
        'cuda_available': torch.cuda.is_available()
    })

@app.route('/api/languages', methods=['GET'])
def get_languages():
    """Get supported languages"""
    supported_languages = [
        'en', 'ar', 'es', 'fr', 'de', 'it', 'pt',
        'ja', 'zh', 'ko', 'ru', 'pl', 'nl', 'tr',
        'sv', 'fi', 'no', 'da'
    ]
    return jsonify({
        'languages': supported_languages,
        'total': len(supported_languages)
    })

@app.route('/api/tts', methods=['POST'])
def synthesize():
    """
    Generate speech from text using XTTS v2
    
    POST /api/tts
    {
        "text": "Hello, how are you?",
        "language": "en",
        "speaker": "user",
        "ref_audio_base64": "base64_encoded_wav_audio_optional",
        "temperature": 0.75,
        "speed": 1.0,
        "top_p": 0.85,
        "top_k": 50
    }
    """
    try:
        if not tts:
            return jsonify({'error': 'TTS model not loaded'}), 503

        data = request.get_json()
        text = data.get('text', '').strip()
        language = data.get('language', 'en')
        speaker = data.get('speaker', 'default')
        ref_audio_base64 = data.get('ref_audio_base64')
        
        # Optional parameters
        temperature = data.get('temperature', 0.75)
        speed = data.get('speed', 1.0)
        top_p = data.get('top_p', 0.85)
        top_k = data.get('top_k', 50)

        if not text:
            return jsonify({'error': 'Text is required'}), 400

        logger.info(f"Synthesizing: language={language}, speaker={speaker}, text_length={len(text)}")

        # Handle voice cloning with reference audio
        if ref_audio_base64:
            import base64
            import tempfile
            
            # Decode base64 audio
            audio_bytes = base64.b64decode(ref_audio_base64)
            
            # Save to temporary file
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
                tmp.write(audio_bytes)
                ref_audio_path = tmp.name
            
            try:
                # Generate speech with voice cloning
                logger.info(f"Using reference audio for voice cloning")
                wav = tts.tts_with_vc(
                    text=text,
                    language_idx=language,
                    speaker_wav=ref_audio_path,
                    temperature=temperature,
                    top_p=top_p,
                    top_k=top_k,
                    speed=speed
                )
            finally:
                # Clean up temporary file
                if os.path.exists(ref_audio_path):
                    os.remove(ref_audio_path)
        else:
            # Generate speech without voice cloning
            wav = tts.tts(
                text=text,
                language_idx=language,
                temperature=temperature,
                top_p=top_p,
                top_k=top_k,
                speed=speed
            )

        # Convert to audio buffer
        audio_buffer = io.BytesIO()
        tts.save_wav(wav, audio_buffer)
        audio_buffer.seek(0)

        logger.info(f"✅ Speech synthesis completed for {language}")

        return send_file(
            audio_buffer,
            mimetype='audio/wav',
            as_attachment=True,
            download_name=f'tts_{language}.wav'
        )

    except Exception as e:
        logger.error(f"❌ TTS Error: {e}", exc_info=True)
        return jsonify({'error': str(e)}), 500

@app.route('/api/tts/batch', methods=['POST'])
def synthesize_batch():
    """
    Generate speech for multiple languages in one request
    
    POST /api/tts/batch
    {
        "text": "Hello",
        "languages": ["en", "ar", "es"],
        "ref_audio_base64": "base64_optional"
    }
    """
    try:
        if not tts:
            return jsonify({'error': 'TTS model not loaded'}), 503

        data = request.get_json()
        text = data.get('text', '').strip()
        languages = data.get('languages', ['en'])
        ref_audio_base64 = data.get('ref_audio_base64')

        if not text:
            return jsonify({'error': 'Text is required'}), 400

        logger.info(f"Batch synthesis: {len(languages)} languages")

        results = {}
        
        for language in languages:
            try:
                if ref_audio_base64:
                    import base64
                    import tempfile
                    
                    audio_bytes = base64.b64decode(ref_audio_base64)
                    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
                        tmp.write(audio_bytes)
                        ref_audio_path = tmp.name
                    
                    try:
                        wav = tts.tts_with_vc(
                            text=text,
                            language_idx=language,
                            speaker_wav=ref_audio_path
                        )
                    finally:
                        if os.path.exists(ref_audio_path):
                            os.remove(ref_audio_path)
                else:
                    wav = tts.tts(text=text, language_idx=language)

                # Convert to WAV buffer
                buffer = io.BytesIO()
                tts.save_wav(wav, buffer)
                buffer.seek(0)
                audio_data = buffer.getvalue()
                
                # Encode to base64 for JSON response
                import base64
                results[language] = {
                    'status': 'completed',
                    'audio_base64': base64.b64encode(audio_data).decode()
                }
                logger.info(f"✅ Generated audio for {language}")

            except Exception as e:
                logger.error(f"❌ Error synthesizing {language}: {e}")
                results[language] = {
                    'status': 'failed',
                    'error': str(e)
                }

        return jsonify({
            'success': True,
            'text': text,
            'languages': results
        })

    except Exception as e:
        logger.error(f"❌ Batch TTS Error: {e}", exc_info=True)
        return jsonify({'error': str(e)}), 500

@app.route('/api/model/info', methods=['GET'])
def model_info():
    """Get model information"""
    return jsonify({
        'model': 'XTTS v2',
        'provider': 'Coqui TTS',
        'device': device,
        'cuda_available': torch.cuda.is_available(),
        'torch_version': torch.__version__,
        'supported_languages': [
            'en', 'ar', 'es', 'fr', 'de', 'it', 'pt',
            'ja', 'zh', 'ko', 'ru', 'pl', 'nl', 'tr',
            'sv', 'fi', 'no', 'da'
        ]
    })

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8000))
    logger.info(f"🚀 Starting Noota XTTS Server on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
