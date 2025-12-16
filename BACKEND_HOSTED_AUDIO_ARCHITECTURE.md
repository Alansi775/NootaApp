# 🎙️ Backend-Hosted Audio Architecture

## **الفلسفة: استقلالية كاملة من Firebase**

```
┌─────────────────────────────────────────────────────────────┐
│  Firebase: Metadata Only (Rooms, Users, Text, Status)       │
│  Backend: Handles Files, Processing, Audio Generation      │
│  iOS: Sends audio + text to Backend, Listens via Firestore │
└─────────────────────────────────────────────────────────────┘
```

---

## **1️⃣ iOS → Backend (Upload Message with Audio)**

### الخطوات:

```swift
// في ConversationViewModel.toggleContinuousRecording()
speechManager.startAudioRecording()  // 🎙️ ابدأ التسجيل

// عند قول الجملة:
speechManager.completedSentencePublisher  // إرسال الجملة

// في sendOriginalMessage():
let audioURL = speechManager.stopAudioRecording()  // 🎙️ احصل على الملف

// Create multipart/form-data
let boundary = UUID().uuidString
var body = Data()

// Add fields: roomID, senderUID, originalText, languageCode
// Add file: audioFile (binary)

// POST to Backend
POST /api/messages/create
Content-Type: multipart/form-data

--boundary
Content-Disposition: form-data; name="roomID"
room123
--boundary
Content-Disposition: form-data; name="senderUID"  
user456
--boundary
Content-Disposition: form-data; name="originalText"
مرحبا بالعالم
--boundary
Content-Disposition: form-data; name="originalLanguageCode"
ar-SA
--boundary
Content-Disposition: form-data; name="audioFile"; filename="audio.wav"
Content-Type: audio/wav
[BINARY AUDIO DATA 50KB]
--boundary--
```

---

## **2️⃣ Backend - Receive & Store**

### API Endpoint: `POST /api/messages/create`

```javascript
// في src/index.js

app.post('/api/messages/create', voiceUpload.single('audioFile'), async (req, res) => {
  // 1️⃣ استقبل الملف الصوتي
  const audioFile = req.file;
  // مثال: audioFile = {
  //   filename: 'voice_user456_1702645890000.wav',
  //   path: '/uploads/voice/voice_user456_1702645890000.wav',
  //   size: 51200
  // }

  // 2️⃣ احفظ الرسالة في Firestore
  const message = {
    senderUID: 'user456',
    originalText: 'مرحبا بالعالم',
    originalLanguageCode: 'ar-SA',
    originalAudioUrl: 'http://localhost:5001/audio/voice/voice_user456_1702645890000.wav',
    processingStatus: 'pending',  // ⭐ Signal to start processing
    audioUrls: {},
    translations: {}
  };

  await Firestore.collection('rooms').doc(roomID).collection('messages').add(message);

  res.json({ success: true, messageID: 'msg123' });
});
```

### ملفات النظام:

```
/uploads/
├── voice/
│   ├── voice_user456_1702645890000.wav    ← الملف الصوتي الأصلي للمستخدم
│   └── voice_user789_1702645891000.wav
│
└── audio/
    └── chunks/
        ├── ar_msg123_chunk0.wav            ← Chunk 1 بالعربية
        ├── ar_msg123_chunk1.wav            ← Chunk 2 بالعربية
        ├── es_msg123_chunk0.wav            ← Chunk 1 بالإسباني
        └── tr_msg123_chunk0.wav            ← Chunk 1 بالتركي
```

---

## **3️⃣ Backend - Message Listener & Processing**

### يسمع التغييرات في Firestore:

```javascript
// في src/services/messageListener.js

Firestore.collection('rooms').doc(roomID).collection('messages')
  .where('processingStatus', '==', 'pending')
  .onSnapshot(async (snapshot) => {
    for (const doc of snapshot.docChanges()) {
      const message = doc.doc.data();
      
      // ✨ Begin async processing
      processMessage({
        messageId: doc.doc.id,
        roomId: roomID,
        message,
        docRef: doc.doc.ref
      });
    }
  });
```

### معالجة الرسالة:

```javascript
// في src/services/messageProcessor.js

async function processMessage(params) {
  const { messageId, message, docRef } = params;

  // 1️⃣ حمّل ملف الصوت الأصلي من الـ disk
  const userAudioPath = await downloadUserAudio(
    message.originalAudioUrl
  );
  // ← يقرأ من: /uploads/voice/voice_user456_1702645890000.wav

  // 2️⃣ قسّم النص إلى chunks
  const chunks = splitTextIntoChunks(message.originalText);
  // مثال: ["مرحبا", "بالعالم"]

  // 3️⃣ لكل لغة مستقبل (es-ES, tr-TR, ...):
  for (const language of targetLanguages) {
    const langAudioUrls = [];
    const langTranslations = [];

    // 4️⃣ لكل chunk:
    for (let i = 0; i < chunks.length; i++) {
      // ترجم النص
      const translated = await translator.translate(
        chunks[i],
        'ar-SA',
        language
      );

      // اولّد الصوت via XTTS v2
      const audioBuffer = await xtts.generate({
        text: translated,
        language: language,
        speakerWav: userAudioPath  // ⭐ استخدم صوتك!
      });

      // احفظ الـ chunk على الـ disk
      const audioUrl = await uploadAudioChunk(audioBuffer, {
        messageId,
        languageCode: language,
        chunkIndex: i
      });
      // ← ينحفظ في: /uploads/audio/chunks/es_msg123_chunk0.wav
      // ← الـ URL: http://localhost:5001/audio/chunks/es_msg123_chunk0.wav

      langAudioUrls.push(audioUrl);
      langTranslations.push(translated);

      // 🔄 Update Firestore في الوقت الفعلي
      await docRef.update({
        processingStatus: 'partial',
        [`audioUrls.${language}`]: langAudioUrls,
        [`translations.${language}`]: langTranslations,
        processedChunks: i + 1,
        totalChunks: chunks.length
      });
    }
  }

  // 5️⃣ Mark as completed
  await docRef.update({
    processingStatus: 'completed'
  });
}
```

---

## **4️⃣ iOS - Real-Time Listener**

### الـ ViewModel يسمع التحديثات:

```swift
// في ConversationViewModel.setupMessagesListener()

messagesListener = Firestore.firestore()
  .collection("rooms").document(roomID).collection("messages")
  .addSnapshotListener { snapshot in
    
    for document in snapshot!.documents {
      let message = try document.data(as: Message.self)
      
      // إذا كانت الرسالة موجهة إليّ
      if message.senderUID != currentUser.uid {
        
        // 🎙️ استقبل روابط الصوت
        if let audioUrls = message.audioUrls[selectedLanguage] {
          // مثال: ["http://localhost:5001/audio/chunks/es_msg123_chunk0.wav",
          //        "http://localhost:5001/audio/chunks/es_msg123_chunk1.wav"]
          
          // أضفها إلى قائمة الانتظار
          textToSpeechService.enqueueAudioChunks(
            audioUrls,
            totalChunks: message.totalChunks
          );
        }
        
        // 📝 عرض الترجمة
        displayMessage = message.translations[selectedLanguage]?.first
      }
    }
  }
```

### الـ Audio Queue Service:

```swift
// في TextToSpeechService.swift

func enqueueAudioChunks(_ audioUrls: [String]) {
  audioQueue.append(contentsOf: audioUrls)
  
  // بدء التشغيل إذا لم يكن جاري
  if !isProcessingQueue {
    processQueue()
  }
}

func processQueue() {
  guard let nextUrl = audioQueue.first else {
    isSpeaking = false
    return
  }
  
  Task {
    // 1️⃣ حمّل الملف من Backend
    let (data, _) = try await URLSession.shared.data(from: URL(string: nextUrl)!)
    
    // 2️⃣ شغّله
    let player = try AVAudioPlayer(data: data, fileTypeHint: "wav")
    player.delegate = self
    audioPlayer = player
    audioPlayer?.play()
  }
}

// عند انتهاء التشغيل:
func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
  // أزل من القائمة
  audioQueue.removeFirst()
  
  // شغّل الـ chunk التالي
  processQueue()
}
```

---

## **🌍 الـ URLs النهائية**

| الملف | المسار | الـ URL |
|------|--------|--------|
| صوتك الأصلي | `/uploads/voice/voice_user456_ts.wav` | `http://localhost:5001/audio/voice/voice_user456_ts.wav` |
| Chunk 1 (عربي) | `/uploads/audio/chunks/ar_msg123_chunk0.wav` | `http://localhost:5001/audio/chunks/ar_msg123_chunk0.wav` |
| Chunk 1 (إسباني) | `/uploads/audio/chunks/es_msg123_chunk0.wav` | `http://localhost:5001/audio/chunks/es_msg123_chunk0.wav` |

---

## **💾 البيانات في Firestore (Metadata فقط)**

```json
{
  "messageId": "msg123",
  "senderUID": "user456",
  "originalText": "مرحبا بالعالم",
  "originalLanguageCode": "ar-SA",
  "originalAudioUrl": "http://localhost:5001/audio/voice/voice_user456_ts.wav",
  "targetLanguageCode": "es-ES",
  "processingStatus": "completed",
  "audioUrls": {
    "es-ES": [
      "http://localhost:5001/audio/chunks/es_msg123_chunk0.wav",
      "http://localhost:5001/audio/chunks/es_msg123_chunk1.wav"
    ],
    "tr-TR": [
      "http://localhost:5001/audio/chunks/tr_msg123_chunk0.wav",
      "http://localhost:5001/audio/chunks/tr_msg123_chunk1.wav"
    ]
  },
  "translations": {
    "es-ES": ["Hola", "al mundo"],
    "tr-TR": ["Merhaba", "dünyaya"]
  },
  "totalChunks": 2,
  "processedChunks": 2,
  "timestamp": 1702645890000
}
```

---

## **✅ الفوائد**

| الميزة | التفصيل |
|------|--------|
| **💰 مجاني** | بدون Firebase Storage cost |
| **⚡ سريع** | الملفات على Backend نفسه |
| **🔒 آمن** | الملفات محفوظة على سيرفرك |
| **📊 كامل التحكم** | يمكنك تعديل أي شيء بدون قيود |
| **🚀 Scalable** | إذا كبرت، انقل إلى S3 فقط |
| **🎯 Real-time** | Firestore للـ metadata، Backend للـ files |

---

## **🚀 البدء**

```bash
# 1. تثبيت multer
cd NootaBackend
npm install multer

# 2. تأكد من الـ .env
cat .env | grep BACKEND_URL

# 3. ابدأ الـ Backend
npm run dev

# 4. في Xcode، ابدأ التطبيق
# الآن يرسل الصوت مباشرة للـ Backend! 🎙️
```

---

**الآن أنت مستقل تماماً! 🎉**
