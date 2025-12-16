# 🚀 **QUICK START - Backend-Hosted Audio**

## **⚡ 3 خطوات للبدء:**

### **1. تثبيت multer:**
```bash
cd NootaBackend
npm install multer
```

### **2. شغّل Backend:**
```bash
npm run dev
```

**Expected:**
```
🚀 Noota Backend Server running on port 5001
✅ Firestore instance created successfully
Message listener started
```

### **3. في Xcode - شغّل التطبيق:**
```
Cmd + R
```

---

## **✅ What Happens Next:**

```
1. ابدأ محادثة
2. iOS يسجل صوتك
3. Backend يستقبل + يعالج
4. الصوت يشتغل لـ الـ users الآخرين بلغاتهم!
```

---

## **📝 مثال عملي:**

```
أنت (عربي): "مرحبا"
    ↓
iOS sends to Backend: 
  - Text: "مرحبا"
  - Audio: [51KB WAV file]
    ↓
Backend processes:
  - Saves voice: /uploads/voice/...
  - Translates: "مرحبا" → "Hola" (Spanish)
  - Generates audio with YOUR voice
  - Saves: /uploads/audio/chunks/...
    ↓
Spanish user receives:
  - Text: "Hola"
  - Audio: Your voice saying "Hola"
  - ✅ No gaps, seamless playback!
```

---

## **🔍 Verify Everything Works:**

```bash
# Check voice files uploaded
ls -la NootaBackend/uploads/voice/

# Check generated chunks
ls -la NootaBackend/uploads/audio/chunks/
```

---

## **❓ Troubleshooting:**

### **Backend not starting?**
```bash
# Check port 5001 is free
lsof -i :5001

# Kill if needed
kill -9 <PID>

# Restart
npm run dev
```

### **Audio files not saving?**
```bash
# Create directories manually
mkdir -p NootaBackend/uploads/voice
mkdir -p NootaBackend/uploads/audio/chunks

# Check permissions
chmod 755 NootaBackend/uploads
```

### **iOS can't reach Backend?**
```swift
// In ConversationViewModel.sendOriginalMessage()
// Change from:
let backendURL = "http://localhost:5001/api/messages/create"

// To your Mac's IP:
let backendURL = "http://192.168.1.100:5001/api/messages/create"

// Get Mac IP:
// System Preferences → Network → IP Address
```

---

## **📊 Architecture in One Image:**

```
iOS (Record) → Backend (Process) → Firestore (Metadata)
                                    ↓
                              (Real-time Updates)
                                    ↓
                            iOS (Play Chunks)
```

---

**That's it! You're ready to go! 🎉**

يلا نختبر النظام! 🚀
