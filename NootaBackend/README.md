# Noota Backend Server

Professional Node.js Backend for Noota iOS App with XTTS v2 Text-to-Speech Integration

## 🚀 Features

- **XTTS v2 Integration**: Advanced voice cloning and multi-language TTS
- **Real-time Message Processing**: Firestore listeners for instant message handling
- **Multi-language Support**: Automatic translation and speech generation for 17+ languages
- **Firebase Integration**: Real-time database, storage, and authentication
- **Voice Cloning**: Preserve original speaker characteristics across languages
- **Error Handling**: Robust error handling with automatic retry and failed message reprocessing
- **Production Ready**: Logging, monitoring, and health checks included

## 📋 Prerequisites

- Node.js 16+ (LTS recommended)
- Firebase Project with Firestore and Storage enabled
- Google Cloud API Key (for translation service)
- XTTS v2 Server running (Python backend with TTS.ai)
- macOS, Linux, or Windows development environment

## 🔧 Installation

1. **Clone or download the backend folder**
   ```bash
   cd NootaBackend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure environment variables**
   ```bash
   cp .env.example .env
   ```

4. **Edit `.env` file with your credentials**
   ```
   FIREBASE_PROJECT_ID=your-project-id
   FIREBASE_PRIVATE_KEY=your-private-key
   FIREBASE_CLIENT_EMAIL=your-email
   FIREBASE_DATABASE_URL=your-database-url
   FIREBASE_STORAGE_BUCKET=your-bucket.appspot.com
   
   GOOGLE_CLOUD_API_KEY=your-google-cloud-key
   
   XTTS_SERVER_URL=http://localhost:8000
   PORT=5000
   NODE_ENV=development
   ```

## 🎯 Quick Start

### Development Mode (with auto-reload)

```bash
npm run dev
```

### Production Mode

```bash
npm start
```

The server will start on `http://localhost:5000`

## 📡 API Endpoints

### Health Check
```bash
GET /api/health
GET /api/health/detailed
```

### Message Processing
```bash
# Get message processing status
GET /api/messages/status/:roomId/:messageId

# Reprocess failed message
POST /api/messages/reprocess/:roomId/:messageId

# Get all messages in room
GET /api/messages/room/:roomId
```

## 🔄 How It Works

1. **Message Received**: iOS app sends message to Firestore with status `pending`

2. **Listener Detection**: Backend real-time listener detects new/pending messages

3. **Translation**: Text is translated to all languages in the room using Google Cloud Translation

4. **Speech Generation**: XTTS v2 generates audio for each language, preserving the speaker's voice

5. **Upload**: Audio files are uploaded to Firebase Storage with public URLs

6. **Update**: Firestore message is updated with:
   - `translations`: {en: "Hello", ar: "مرحبا", ...}
   - `audioUrls`: {en: "gs://...", ar: "gs://...", ...}
   - `processingStatus`: "completed"

7. **Display**: iOS app receives real-time update and displays message with audio playback

## 🐍 XTTS v2 Python Backend Setup

### Quick Setup (Using TTS.ai Library)

```bash
# Create Python virtual environment
python3 -m venv xtts_env
source xtts_env/bin/activate

# Install TTS.ai
pip install TTS torch
pip install flask flask-cors

# Create server.py
```

### server.py (Python XTTS Server)

```python
from flask import Flask, request, send_file
from TTS.api import TTS
import torch
import io
import os

app = Flask(__name__)

# Initialize XTTS model
device = "cuda" if torch.cuda.is_available() else "cpu"
tts = TTS("tts_models/multilingual/multi_speaker/xtts_v2", gpu=(device == "cuda"))

@app.route('/api/tts', methods=['POST'])
def synthesize():
    data = request.json
    text = data.get('text')
    language = data.get('language', 'en')
    
    # Reference audio for voice cloning (optional)
    ref_audio = data.get('ref_audio_base64')
    
    # Generate speech
    if ref_audio:
        # Use voice cloning
        audio = tts.tts_with_vc(text, language_idx=language, speaker_wav=ref_audio)
    else:
        # Use default speaker
        audio = tts.tts(text, language_idx=language)
    
    # Save to buffer and return
    audio_buffer = io.BytesIO()
    tts.save_wav(audio, audio_buffer)
    audio_buffer.seek(0)
    
    return send_file(audio_buffer, mimetype='audio/wav')

@app.route('/health', methods=['GET'])
def health():
    return {'status': 'healthy'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
```

### Run XTTS Server

```bash
python server.py
```

## 🗂️ Project Structure

```
NootaBackend/
├── src/
│   ├── config/
│   │   ├── firebase.js           # Firebase Admin SDK initialization
│   │   ├── logger.js             # Pino logger setup
│   │   └── translation.js        # Google Cloud Translation config
│   ├── routes/
│   │   ├── messages.js           # Message API endpoints
│   │   └── health.js             # Health check endpoints
│   ├── services/
│   │   ├── messageListener.js    # Firestore real-time listener
│   │   ├── messageProcessor.js   # Core message processing logic
│   │   ├── xttsService.js        # XTTS v2 speech generation
│   │   └── storageService.js     # Firebase Storage uploads
│   └── index.js                  # Express server entry point
├── .env.example                  # Environment variables template
├── .gitignore                    # Git ignore rules
├── package.json                  # Dependencies
└── README.md                     # This file
```

## 🔐 Environment Variables

See `.env.example` for all available options:

| Variable | Required | Description |
|----------|----------|-------------|
| `FIREBASE_PROJECT_ID` | Yes | Firebase project ID |
| `FIREBASE_PRIVATE_KEY` | Yes | Firebase service account key |
| `FIREBASE_CLIENT_EMAIL` | Yes | Firebase service account email |
| `FIREBASE_DATABASE_URL` | Yes | Firestore database URL |
| `FIREBASE_STORAGE_BUCKET` | Yes | Firebase Storage bucket |
| `GOOGLE_CLOUD_API_KEY` | Yes | Google Cloud API key for translation |
| `XTTS_SERVER_URL` | Yes | XTTS v2 server URL (default: http://localhost:8000) |
| `PORT` | No | Server port (default: 5000) |
| `NODE_ENV` | No | Environment (default: development) |
| `LOG_LEVEL` | No | Log level (default: info) |

## 📊 Message Processing Flow

```
iOS App sends message
        ↓
Firestore collection (processingStatus: "pending")
        ↓
Backend Listener detects
        ↓
Set processingStatus: "processing"
        ↓
Google Cloud Translation API
(Translate to all room languages)
        ↓
XTTS v2 Service
(Generate audio with voice cloning)
        ↓
Firebase Storage
(Upload audio files)
        ↓
Update Firestore:
- translations: {en, ar, es, ...}
- audioUrls: {gs://..., gs://..., ...}
- processingStatus: "completed"
        ↓
iOS App receives real-time update
        ↓
Display message with audio playback
```

## 🐛 Troubleshooting

### XTTS Server Connection Failed
```
❌ Error: connect ECONNREFUSED 127.0.0.1:8000
```
- Ensure XTTS Python server is running on port 8000
- Check `XTTS_SERVER_URL` in `.env`

### Firebase Authentication Error
```
❌ Error: Invalid service account
```
- Verify Firebase credentials in `.env`
- Ensure all required Firebase keys are present
- Check key format (private key should have newlines as `\n`)

### Translation API Error
```
❌ Error: 401 Unauthorized
```
- Verify Google Cloud API key is valid
- Ensure Translation API is enabled in Google Cloud Console
- Check API key has correct permissions

### Message Not Processing
- Check Firebase Firestore rules allow backend write access
- Verify message has `processingStatus: "pending"`
- Check backend logs for errors: `tail -f logs/app.log`
- Verify all room languages are in supported languages list

## 📝 Logging

Logs are output to console with pretty formatting in development mode.

In production, logs are JSON formatted for easy parsing:

```bash
# View logs
npm start | grep '"level"'

# Filter for errors
npm start 2>&1 | grep '"level":50'
```

## 🚀 Deployment

### Deploy to Google Cloud Run

```bash
# Create Dockerfile
echo 'FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY src ./src
EXPOSE 8080
CMD ["node", "src/index.js"]' > Dockerfile

# Build and deploy
gcloud run deploy noota-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --set-env-vars FIREBASE_PROJECT_ID=... \
  --memory 2Gi
```

### Deploy to Heroku

```bash
git push heroku main
heroku config:set FIREBASE_PROJECT_ID=...
heroku logs --tail
```

## 📞 Support

For issues or questions:
1. Check logs: `npm run dev`
2. Test endpoints: `curl http://localhost:5000/api/health`
3. Verify Firebase connection
4. Verify XTTS server is running

## 📄 License

MIT License - Feel free to use and modify
