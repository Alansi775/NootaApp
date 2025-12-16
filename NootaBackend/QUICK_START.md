# 🚀 Noota Backend - Quick Start Guide

Get your XTTS v2 Backend running in 15 minutes!

## Prerequisites Check

```bash
# Check Node.js (v16+)
node --version

# Check Python (v3.8+)
python3 --version
```

## One-Command Setup (macOS/Linux)

```bash
cd NootaBackend
bash setup.sh
```

This will:
1. ✅ Install Node.js dependencies
2. ✅ Install Python XTTS dependencies
3. ✅ Create `.env` file from template
4. ✅ Create Python virtual environment

## Manual Step-by-Step Setup

### Step 1: Setup Node.js Backend

```bash
cd NootaBackend

# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Edit environment variables (add your Firebase & Google Cloud credentials)
nano .env
```

### Step 2: Setup Python XTTS Server

```bash
# Create virtual environment
python3 -m venv xtts_env
source xtts_env/bin/activate

# Install dependencies (takes 5-10 minutes)
pip install TTS torch flask flask-cors python-dotenv
```

### Step 3: Start Both Servers

Open **two terminal windows**:

**Terminal 1 - XTTS v2 Server**
```bash
source xtts_env/bin/activate
python xtts_server.py
```

Output:
```
Using device: cuda
✅ XTTS v2 model loaded successfully
🚀 Starting Noota XTTS Server on port 8000
```

**Terminal 2 - Node.js Backend**
```bash
npm start
# or for development with auto-reload:
npm run dev
```

Output:
```
🚀 Noota Backend Server running on port 5000
📡 Environment: development
```

## Test the Setup

```bash
# Test Node.js Backend
curl http://localhost:5000/api/health

# Test XTTS Server
curl http://localhost:8000/health

# Expected responses:
# {"success":true,"status":"healthy",...}
# {"status":"healthy","model":"XTTS v2",...}
```

## Configure Firebase Credentials

Edit `.env` file with your credentials:

```bash
nano .env
```

### Get Firebase Credentials

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to Settings > Service Accounts
4. Click "Generate new private key"
5. Copy the JSON content into `.env`:

```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxx@project-id.iam.gserviceaccount.com
FIREBASE_DATABASE_URL=https://project-id.firebaseio.com
FIREBASE_STORAGE_BUCKET=project-id.appspot.com
```

### Get Google Cloud API Key

1. Go to Google Cloud Console: https://console.cloud.google.com
2. Enable "Cloud Translation API"
3. Create API key (APIs & Services > Credentials)
4. Add to `.env`:

```env
GOOGLE_CLOUD_API_KEY=AIzaSy...
```

## Verify Integration

Once both servers are running:

1. **Check Backend health**
   ```bash
   curl http://localhost:5000/api/health/detailed
   ```
   
   Should show:
   ```json
   {
     "services": {
       "xtts": { "status": "connected" },
       "firebase": { "status": "configured" },
       "messageListener": { "status": "active" }
     }
   }
   ```

2. **Send a test message from iOS app** - It should:
   - Appear in Firestore with `processingStatus: "pending"`
   - Be picked up by Backend listener
   - Show `processingStatus: "processing"`
   - After 5-30 seconds, show `processingStatus: "completed"` with audio URLs
   - Be displayed in iOS app with play button

## Environment Variables

| Variable | Example | Get From |
|----------|---------|----------|
| `FIREBASE_PROJECT_ID` | `noota-prod` | Firebase Console |
| `FIREBASE_PRIVATE_KEY` | `-----BEGIN PRIVATE KEY-----...` | Firebase Service Account |
| `FIREBASE_CLIENT_EMAIL` | `firebase-adminsdk-xx@...` | Firebase Service Account |
| `FIREBASE_DATABASE_URL` | `https://noota-prod.firebaseio.com` | Firebase Console |
| `FIREBASE_STORAGE_BUCKET` | `noota-prod.appspot.com` | Firebase Console |
| `GOOGLE_CLOUD_API_KEY` | `AIzaSy...` | Google Cloud Console |
| `XTTS_SERVER_URL` | `http://localhost:8000` | Local XTTS server |
| `PORT` | `5000` | Any free port |
| `NODE_ENV` | `development` | development or production |

## Troubleshooting

### "Cannot find module 'express'"
```bash
npm install
```

### "No module named TTS"
```bash
source xtts_env/bin/activate
pip install TTS
```

### "ECONNREFUSED - Cannot connect to XTTS"
- Make sure XTTS server is running in another terminal
- Check `XTTS_SERVER_URL` in `.env` matches actual server URL
- Run `python xtts_server.py` in virtual environment

### "Firebase authentication failed"
- Verify all Firebase credentials in `.env`
- Download new service account key from Firebase Console
- Ensure `FIREBASE_PRIVATE_KEY` has proper newlines (replace `\n` literally)

### "CUDA out of memory"
- XTTS will fall back to CPU automatically
- Generation will be slower (15-30 seconds instead of 2-5)
- For production, use GPU server (Google Cloud Run with GPU, AWS EC2 with GPU, etc.)

### Messages not being processed
- Check Backend logs for errors
- Verify Firestore rules allow Backend write access
- Ensure message has `processingStatus: "pending"` initially
- Check that room has `languages` field configured

## Performance Tips

1. **Use GPU** - Significantly faster (2-4 seconds vs 15-30 seconds per message)
2. **Minimize latency** - Deploy Backend close to users
3. **Cache reference audio** - Speeds up voice cloning
4. **Batch processing** - Process multiple messages in parallel
5. **Use message queue** - For high-volume scenarios

## Next Steps

1. ✅ Backend running locally
2. 📱 Test from iOS app (should send messages to Firestore)
3. 🌍 Deploy to production (Google Cloud Run recommended)
4. 📊 Monitor with logging and error tracking

## Need Help?

Check:
1. Console logs (both terminals)
2. Firebase Firestore console (see message status)
3. Backend logs: look for "Processing message" entries
4. Test endpoints: `/api/health/detailed` shows service status

Good luck! 🎉
