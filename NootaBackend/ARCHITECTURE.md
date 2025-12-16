# 🏗️ Noota System Architecture

Complete system design: iOS App + Node.js Backend + XTTS v2 + Firebase

## System Overview

```
┌─────────────────┐
│   iOS App       │
│   (SwiftUI)     │
└────────┬────────┘
         │
         │ Sends message
         │ with text + language
         │
         ▼
┌─────────────────────────────────┐
│     Firebase Firestore          │
│  Message Status: "pending"      │
│  {text, language, senderId...}  │
└────────┬────────────────────────┘
         │
         │ Real-time listener
         │
         ▼
┌──────────────────────────────────────┐
│   Node.js Backend (Port 5000)        │
│                                      │
│  1. Translate text (Google Cloud)   │
│  2. Generate speech (XTTS v2)       │
│  3. Upload audio (Firebase Storage) │
│  4. Update message status           │
└────────┬────────┬────────┬──────────┘
         │        │        │
    ┌────▼─┐  ┌──▼───┐ ┌──▼────────┐
    │      │  │      │ │           │
    ▼      ▼  ▼      ▼ ▼           ▼
  Google  XTTS   Firebase   Firebase
  Cloud   v2     Firestore  Storage
  Translate  (Port 8000)    (Audio files)
  (API)       (Python)      (gs://...)
    │      │  │      │ │           │
    └────┬─┘  └──┬───┘ └──┬────────┘
         │       │        │
         │  Updates message
         │  - translations
         │  - audioUrls
         │  - processingStatus: "completed"
         │
         ▼
┌─────────────────────────────────┐
│     Firebase Firestore          │
│  Message Status: "completed"    │
│  {translations, audioUrls...}   │
└────────┬────────────────────────┘
         │
         │ Real-time listener
         │ (iOS subscribed)
         │
         ▼
┌─────────────────────────────────────┐
│   iOS App (Conversation View)       │
│                                     │
│  - Shows message translation        │
│  - Displays play button             │
│  - Downloads audio from Storage     │
│  - Plays audio using AVAudioPlayer │
└─────────────────────────────────────┘
```

## Component Details

### 1. iOS App (Noota.xcodeproj)

**Responsibility**: Send messages, display content, play audio

**Key Files**:
- `Message.swift` - Data model with translations & audioUrls
- `ConversationViewModel.swift` - Message processing & audio playback
- `ChatBubbleView.swift` - UI with audio controls
- `TextToSpeechService.swift` - Remote audio playback
- `FirestoreService.swift` - Real-time message listeners

**Flow**:
```
User types message
    ↓
Send to Firestore (processingStatus: "pending")
    ↓
Listen for processingStatus: "completed"
    ↓
Display translations
    ↓
Download audio URL
    ↓
Play with AVAudioPlayer
```

### 2. Node.js Backend (NootaBackend/)

**Responsibility**: Process messages, translate, generate audio, manage storage

**Key Files**:
- `src/index.js` - Express server entry point
- `src/services/messageListener.js` - Firestore real-time listener
- `src/services/messageProcessor.js` - Core processing logic
- `src/services/xttsService.js` - XTTS API client
- `src/services/storageService.js` - Firebase Storage uploads
- `src/config/translation.js` - Google Cloud Translation API

**Message Processing Flow**:
```
Firestore listener detects message (processingStatus: "pending")
    ↓
Mark as processingStatus: "processing"
    ↓
Extract text & language
    ↓
Get room languages configuration
    ↓
Translate text to all languages (Google Cloud Translation)
    ↓
For each language:
  - Generate speech (XTTS v2)
  - Upload audio file (Firebase Storage)
    ↓
Update Firestore with:
  - translations: {en: "...", ar: "...", ...}
  - audioUrls: {en: "gs://...", ar: "gs://...", ...}
  - processingStatus: "completed"
```

### 3. XTTS v2 Python Server (xtts_server.py)

**Responsibility**: Generate speech with voice cloning for multiple languages

**Port**: 8000

**Endpoints**:
- `POST /api/tts` - Generate speech for single language
- `POST /api/tts/batch` - Generate speech for multiple languages
- `GET /health` - Health check
- `GET /api/languages` - Supported languages
- `GET /api/model/info` - Model information

**Features**:
- Voice cloning using reference audio
- 17+ language support
- Real-time audio generation
- Optional temperature & speed parameters
- Base64 audio response

**Performance**:
- GPU (NVIDIA Tesla T4): 2-4 seconds per language
- GPU (Apple Silicon): 5-10 seconds per language
- CPU: 15-30 seconds per language

### 4. Firebase Infrastructure

**Firestore Collections**:
```
rooms/
  ├── {roomId}
  │   ├── messages/
  │   │   ├── {messageId}
  │   │   │   ├── text: "Hello"
  │   │   │   ├── senderId: "user123"
  │   │   │   ├── senderName: "Ahmed"
  │   │   │   ├── senderLanguage: "ar"
  │   │   │   ├── processingStatus: "pending|processing|completed|failed"
  │   │   │   ├── translations: {en: "...", ar: "...", ...}
  │   │   │   ├── audioUrls: {en: "gs://...", ar: "gs://...", ...}
  │   │   │   ├── timestamp: 2024-12-11T...
  │   │   │   └── processingError: "error message if failed"
  │   │
  │   └── {roomId data}
  │       ├── name: "Room Name"
  │       ├── languages: ["en", "ar", "es"]
  │       ├── members: ["user1", "user2"]
  │       └── createdAt: ...

users/
  ├── {userId}
  │   ├── name: "Ahmed"
  │   ├── language: "ar"
  │   ├── email: "...@gmail.com"
  │   └── referenceAudioUrl: "gs://..." (for voice cloning)
```

**Firebase Storage Structure**:
```
gs://bucket-name/
  └── audio/messages/
      ├── {roomId}/
      │   └── {messageId}/
      │       ├── en.wav
      │       ├── ar.wav
      │       ├── es.wav
      │       └── ...
```

## Message Lifecycle

### State 1: Pending (iOS sends)
```javascript
{
  text: "Hello, how are you?",
  senderId: "user123",
  senderLanguage: "en",
  processingStatus: "pending",
  timestamp: Date.now()
}
```

### State 2: Processing (Backend received)
```javascript
{
  text: "Hello, how are you?",
  senderId: "user123",
  senderLanguage: "en",
  processingStatus: "processing",
  processingStartedAt: Date.now()
}
```

### State 3: Completed (Backend processed)
```javascript
{
  text: "Hello, how are you?",
  senderId: "user123",
  senderLanguage: "en",
  processingStatus: "completed",
  translations: {
    en: "Hello, how are you?",
    ar: "مرحبا، كيف حالك؟",
    es: "Hola, ¿cómo estás?",
    fr: "Bonjour, comment allez-vous?"
  },
  audioUrls: {
    en: "gs://bucket/audio/messages/room1/msg1/en.wav",
    ar: "gs://bucket/audio/messages/room1/msg1/ar.wav",
    es: "gs://bucket/audio/messages/room1/msg1/es.wav",
    fr: "gs://bucket/audio/messages/room1/msg1/fr.wav"
  },
  processedAt: Date.now()
}
```

### State 4: Failed (Errors during processing)
```javascript
{
  text: "Hello, how are you?",
  processingStatus: "failed",
  processingError: "Failed to translate to Spanish: API error",
  failedAt: Date.now()
}
```

## Data Flow Sequence

```
┌─────────────┐
│  iOS App    │
└──────┬──────┘
       │
       │ 1. User types & sends message
       ▼
┌─────────────────────────────────────┐
│  Firestore Document                 │
│  processingStatus: "pending"        │
└──────┬──────────────────────────────┘
       │
       │ 2. Backend listener detects change
       ▼
┌─────────────────────────────────────┐
│  Backend Message Listener           │
│  (messageListener.js)               │
└──────┬──────────────────────────────┘
       │
       │ 3. Update status to "processing"
       ▼
┌─────────────────────────────────────┐
│  Firestore Document                 │
│  processingStatus: "processing"     │
└──────┬──────────────────────────────┘
       │
       │ 4. Process message asynchronously
       ▼
┌─────────────────────────────────────┐
│  messageProcessor.js                │
│  - Get room languages               │
│  - Translate text                   │
│  - Generate speech                  │
│  - Upload audio                     │
└──────┬──────────────────────────────┘
       │
       ├─→ Google Cloud Translation API ──→ translations
       │
       ├─→ XTTS v2 Server
       │   (xtts_server.py)
       │       ├─→ Translate text
       │       ├─→ Clone voice
       │       └─→ Generate audio
       │            ↓
       │       Return WAV audio
       │
       └─→ Firebase Storage
           Upload audio files
                ↓
           Return public URLs
       │
       │ 5. Update Firestore with results
       ▼
┌─────────────────────────────────────┐
│  Firestore Document                 │
│  processingStatus: "completed"      │
│  translations: {...}                │
│  audioUrls: {...}                   │
└──────┬──────────────────────────────┘
       │
       │ 6. iOS listener receives update
       ▼
┌─────────────────────────────────────┐
│  ConversationViewModel              │
│  (Real-time Firestore listener)     │
└──────┬──────────────────────────────┘
       │
       │ 7. Update UI and show message
       ▼
┌─────────────────────────────────────┐
│  ChatBubbleView                     │
│  - Show translation                 │
│  - Show play button                 │
│  - Enable audio playback            │
└──────┬──────────────────────────────┘
       │
       │ 8. User taps play button
       ▼
┌─────────────────────────────────────┐
│  TextToSpeechService                │
│  playRemoteAudio()                  │
│  - Download audio from Storage      │
│  - Play with AVAudioPlayer          │
└─────────────────────────────────────┘
```

## Error Handling

### Translation Failure
```
Issue: Google Cloud Translation API fails
Solution: Fall back to original text
          Include in audioUrls as-is
          Log error in Firestore
```

### XTTS Speech Generation Failure
```
Issue: XTTS server down or model fails
Solution: Retry 3 times (exponential backoff)
          If still fails, mark message as failed
          User can trigger reprocess later
```

### Storage Upload Failure
```
Issue: Firebase Storage quota exceeded
Solution: Check storage quota
          Implement cleanup policy for old audio files
          Consider compression/optimization
```

### Audio Download on iOS
```
Issue: Network timeout downloading audio
Solution: Use URLSessionConfiguration with timeout
          Cache audio locally
          Show retry button in UI
```

## Performance Optimization

### Backend Side
1. **Parallel translation** - Translate to multiple languages in parallel
2. **Parallel speech generation** - Generate audio for multiple languages simultaneously
3. **Caching** - Cache translations for common phrases
4. **Connection pooling** - Reuse Firebase connections
5. **Batch processing** - Process multiple messages together

### iOS Side
1. **Background download** - Download audio in background
2. **Audio caching** - Store downloaded audio locally
3. **Lazy loading** - Only download audio when needed
4. **Compression** - Use compressed audio format

### Infrastructure
1. **CDN** - Use Firebase CDN for storage delivery
2. **Regions** - Deploy backend in same region as users
3. **Load balancing** - Distribute requests across multiple instances
4. **Auto-scaling** - Scale based on demand

## Supported Languages

Currently supported by XTTS v2:
```
English (en)
Arabic (ar)
Spanish (es)
French (fr)
German (de)
Italian (it)
Portuguese (pt)
Japanese (ja)
Chinese (zh)
Korean (ko)
Russian (ru)
Polish (pl)
Dutch (nl)
Turkish (tr)
Swedish (sv)
Finnish (fi)
Norwegian (no)
Danish (da)
```

## Security

### Firebase Rules
```javascript
// Only authenticated users can send messages
match /rooms/{roomId}/messages/{messageId} {
  allow create: if request.auth.uid != null;
  allow read: if request.auth.uid in resource.data.participants;
  allow update: if request.auth.token.firebase.sign_in_provider == 'service_account';
}
```

### API Keys
- Google Cloud API key: Restricted to Translation API only
- Firebase service account: Keep private key secure
- XTTS server: Behind firewall (internal network only)

### Audio Privacy
- Audio files uploaded to Firebase Storage
- Use signed URLs for private access
- Implement TTL (time-to-live) for audio files
- Consider encryption at rest for sensitive data

## Scalability

### Horizontal Scaling
```
Load Balancer
    ├── Backend Instance 1
    ├── Backend Instance 2
    ├── Backend Instance 3
    └── Backend Instance N

Each instance:
- Processes messages independently
- Uses shared Firestore database
- Uploads to shared Firebase Storage
- Queries from shared database
```

### Vertical Scaling
- Increase instance memory (2GB → 4GB → 8GB)
- Increase CPU cores (2 → 4 → 8)
- For XTTS: Upgrade GPU (T4 → V100 → A100)

### Database Scaling
- Firestore auto-scales
- Monitor read/write operations
- Implement caching for repeated queries
- Archive old messages to separate collection

## Monitoring & Observability

### Key Metrics
- Message processing latency (target: < 30 seconds)
- Error rate (target: < 1%)
- XTTS server availability (target: 99.9%)
- Firebase quota utilization
- Backend memory/CPU usage
- Audio file size distribution

### Logging
- Backend logs all message processing steps
- Firebase logs all Firestore operations
- Error tracking (Sentry, Rollbar, etc.)
- XTTS server logs all requests

### Alerts
- High error rate (> 5%)
- XTTS server down
- Firebase quota exceeded
- Backend instance CPU > 80%
- Message processing latency > 60 seconds

## Testing

### Unit Tests
- Message translation logic
- Audio generation parameter validation
- Storage URL generation

### Integration Tests
- End-to-end message processing
- Firebase listener triggers
- Audio file uploads
- iOS audio playback

### Load Tests
- Concurrent messages (100, 1000, 10000)
- Language variations
- Network conditions (slow, offline)
- Storage quota limits

## Future Improvements

1. **Caching** - Cache common translations
2. **Audio quality options** - Allow users to choose quality
3. **Batch processing** - Process multiple messages together
4. **Streaming** - Stream audio as it's generated
5. **Speaker diarization** - Identify multiple speakers
6. **Background removal** - Clean audio processing
7. **Real-time transcription** - Convert audio to text
8. **Voice fingerprinting** - Identify speakers by voice

---

**Diagram Legend**:
- `→` = Data flow
- `↓` = Sequential process
- `|` = Parallel process
- `┌─┐` = Component/Service

For questions or updates, refer to implementation files in respective directories.
