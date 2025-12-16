// يلا نختبر الـ Architecture! 🚀

## **الخطوات لاختبار الـ System:**

### **1️⃣ تأكد من تشغيل Backend:**

```bash
cd NootaBackend
npm run dev
```

**Expected Output:**
```
🚀 Noota Backend Server running on port 5001
📡 Environment: development
🔗 XTTS Server: https://router.huggingface.co/models/coqui/XTTS-v2
📁 Uploads directory: /Users/.../NootaBackend/uploads
✅ Firestore instance created successfully
Message listener started
```

---

### **2️⃣ تأكد من أن الـ Folders موجودة:**

```bash
ls -la NootaBackend/uploads/
# Expected:
# drwxr-xr-x  audio
# drwxr-xr-x  voice

ls -la NootaBackend/uploads/voice/
ls -la NootaBackend/uploads/audio/chunks/
```

---

### **3️⃣ في Xcode: ابدأ التطبيق**

```swift
// في ConversationView:
1. اضغط زر "Start Recording"
2. تحدّث: "مرحبا بالعالم"
3. في الـ console، يجب تشوف:

// iOS Logs:
✅ Audio recording started
📝 Text recognized: "مرحبا بالعالم"
📤 Audio file attached: 51200 bytes
✅ Message sent to Backend successfully (ID: msg_abc123)

// Backend Logs:
📨 Received message from user456
   Text: مرحبا بالعالم...
🎙️ Voice file uploaded: voice_user456_1702645890000.wav (51200 bytes)
✅ Message saved to Firestore: msg_abc123
```

---

### **4️⃣ Backend يبدأ المعالجة:**

```
⏳ Listening for messages...
🔔 NEW MESSAGE DETECTED: msg_abc123
   processingStatus: pending
   senderUID: user456
   originalText: مرحبا بالعالم

📥 Downloading user's original audio for voice cloning...
✅ Loaded user audio: 51200 bytes

📝 Split into 2 chunks:
   - "مرحبا"
   - "بالعالم"

🔄 Starting generation for language: es-ES
   Chunk 1/2: "مرحبا" → es-ES
   
   [XTTS v2 generating...]
   
   📤 Saving audio chunk: es_msg_abc123_chunk0.wav
   ✅ Chunk saved: http://localhost:5001/audio/chunks/es_msg_abc123_chunk0.wav
   ✅ Chunk 1 uploaded and Firestore updated

   [processingStatus: partial, audioUrls.es-ES: [url1], processedChunks: 1]
   
   Chunk 2/2: "بالعالم" → es-ES
   
   [XTTS v2 generating...]
   
   📤 Saving audio chunk: es_msg_abc123_chunk1.wav
   ✅ Chunk saved: http://localhost:5001/audio/chunks/es_msg_abc123_chunk1.wav
   ✅ Chunk 2 uploaded and Firestore updated

   [processingStatus: partial, audioUrls.es-ES: [url1, url2], processedChunks: 2]

✅ Completed language es-ES: 2/2 chunks

🔄 Starting generation for language: tr-TR
   [نفس العملية للتركي...]

🎉 Successfully completed processing message msg_abc123
```

---

### **5️⃣ iOS يستقبل Updates في الوقت الفعلي:**

```
🔔 NEW MESSAGE DETECTED from opponent (ID: msg_abc123)
   Status: processing
   Chunks: 0/2

📝 Adding 1 audio chunk(s) to queue
✅ Audio chunk enqueued (1 in queue)

[شوي من الثوان...]

📝 Adding 1 audio chunk(s) to queue
✅ Audio chunk enqueued (2 in queue)

[الـ queue يبدأ الـ playback:]

⬇️ Downloading audio chunk: http://localhost:5001/audio/chunks/es_...
✅ Audio downloaded (15000 bytes)
▶️ Playing audio chunk (1/2)

[When chunk 1 finishes:]

⬇️ Downloading audio chunk: http://localhost:5001/audio/chunks/es_...
✅ Audio downloaded (15000 bytes)
▶️ Playing audio chunk (2/2)

[When chunk 2 finishes:]

✅ Audio queue completed
```

---

### **6️⃣ في الـ ChatBubbleView:**

```
┌────────────────────────────────────────┐
│ مرحبا               (اسم المرسل)       │
│ ─────────────────────────────────────  │
│ "Hola al mundo"    (الترجمة)            │
│ 📝 1/2 chunks      (التقدم في البداية)  │
│ ─────────────────────────────────────  │
│ [المستخدم يسمع الصوت يُشتغل...]       │
│ ─────────────────────────────────────  │
│ 📝 2/2 chunks      (التقدم بعد شوي)     │
│ ─────────────────────────────────────  │
│ ✅ Ready to play   (الانتهاء)           │
└────────────────────────────────────────┘
```

---

## **🐛 Debugging:**

### **المشكلة: الملفات ما تنحفظ**
```bash
# تحقق من الـ permissions
ls -la NootaBackend/uploads/
chmod -R 755 NootaBackend/uploads/

# إعد إنشاء الـ directories
rm -rf NootaBackend/uploads
npm run dev  # Backend سينشئها تلقائياً
```

### **المشكلة: الـ Backend ما يستقبل الملفات**
```bash
# تأكد من multer installation
npm list multer

# أضيفه إذا ناقص
npm install multer
```

### **المشكلة: iOS ما تقدر توصل للـ Backend**
```swift
// في sendOriginalMessage:
// بدل localhost, استخدم IP الفعلي للـ Mac
let backendURL = "http://192.168.1.100:5001/api/messages/create"
```

---

## **✅ Checklist:**

- [ ] Backend شغّال على port 5001
- [ ] `/uploads/voice/` و `/uploads/audio/chunks/` مواجودة
- [ ] `.env` فيها `BACKEND_URL=http://localhost:5001`
- [ ] iOS تقدر ترسل صوت (check: `📤 Audio file attached` في logs)
- [ ] Backend تستقبل الرسالة (check: `✅ Message saved to Firestore`)
- [ ] MessageProcessor بيبدأ المعالجة (check: `🔄 Starting generation`)
- [ ] iOS تستقبل الـ chunks (check: `📝 Adding X audio chunk(s) to queue`)
- [ ] الصوت يشتغل (check: `▶️ Playing audio chunk`)

---

**يلا نختبر! 🚀**
