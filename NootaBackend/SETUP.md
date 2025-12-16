# 🔧 Backend Server Setup & Configuration

## 📋 نظرة عامة

يوجد خادمان في البيئة الخلفية:

1. **Translation Server** (Node.js) - الخادم الرئيسي للترجمة
2. **XTTS Server** (Python) - خادم النطق الصوتي (اختياري)

---

## 🚀 التشغيل السريع

```bash
# من المشروع الرئيسي
./setup.sh backend-start

# أو يدويّاً
cd NootaBackend
npm install
npm start
```

---

## 🔑 متغيرات البيئة (.env)

**الملف:** `NootaBackend/.env`

```env
# ⚙️ إعدادات الخادم
PORT=5001
NODE_ENV=development
LOG_LEVEL=info

# 🤖 Gemini API
GEMINI_API_KEY=AIzaSy...your_key_here...

# 🔥 Firebase (اختياري)
FIREBASE_PROJECT_ID=noota-abc123
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@project.iam.gserviceaccount.com

# 🎵 XTTS Server
XTTS_URL=http://localhost:5002
XTTS_ENABLED=false

# 📊 إعدادات الأداء
REQUEST_TIMEOUT=30000
MAX_BODY_SIZE=10mb
RATE_LIMIT=100
```

---

## 📦 البنية

```
NootaBackend/
├── src/
│   ├── index.js                    ← نقطة البداية
│   ├── config/
│   │   ├── firebase.js             ← إعداد Firebase
│   │   ├── gemini.js               ← إعداد Gemini
│   │   └── logger.js               ← نظام التسجيل
│   ├── routes/
│   │   ├── translation.js          ← مسارات الترجمة
│   │   └── health.js               ← فحص صحة الخادم
│   └── services/
│       ├── translationService.js   ← خدمة الترجمة
│       ├── audioService.js         ← معالجة الصوت
│       └── firebaseService.js      ← التكامل مع Firebase
├── xtts_server.py                  ← خادم النطق (Python)
├── requirements_xtts.txt           ← المتطلبات (Python)
├── package.json
├── .env.example
└── .gitignore
```

---

## 🌐 API Endpoints

### ✅ Health Check
```bash
GET /health
```
**الرد:**
```json
{
  "status": "ok",
  "timestamp": "2025-12-16T17:00:00Z",
  "uptime": 3600
}
```

### 🔄 الترجمة
```bash
POST /api/translate
Content-Type: application/json

{
  "text": "Hello, how are you?",
  "sourceLanguage": "en-US",
  "targetLanguage": "ar-SA"
}
```

**الرد:**
```json
{
  "original": "Hello, how are you?",
  "translated": "مرحبا، كيف حالك؟",
  "detectedLanguage": "en-US",
  "targetLanguage": "ar-SA"
}
```

### 🎵 النطق الصوتي (XTTS)
```bash
POST /api/tts
Content-Type: application/json

{
  "text": "مرحبا",
  "language": "ar",
  "speaker_wav": "base64_audio_string"
}
```

---

## 🔐 متطلبات مفاتيح API

### Gemini API
1. اذهب إلى [Google AI Studio](https://aistudio.google.com/app/apikeys)
2. انسخ مفتاح API الخاص بك
3. ضعه في `GEMINI_API_KEY` في `.env`

### Firebase Admin SDK (اختياري)
1. اذهب إلى [Firebase Console](https://console.firebase.google.com)
2. Project Settings → Service Accounts
3. انسخ JSON config
4. استخرج:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_PRIVATE_KEY`
   - `FIREBASE_CLIENT_EMAIL`

---

## 🧪 اختبار الخادم

### باستخدام cURL
```bash
# Health Check
curl http://localhost:5001/health

# الترجمة
curl -X POST http://localhost:5001/api/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello",
    "sourceLanguage": "en-US",
    "targetLanguage": "ar-SA"
  }'
```

### باستخدام Postman
1. استورد ملف `NootaBackend/postman_collection.json`
2. عيّن `{{base_url}}` = `http://localhost:5001`
3. اختبر الـ endpoints

---

## 🐛 استكشاف الأخطاء

### ❌ خطأ: "GEMINI_API_KEY is not set"
```bash
# تأكد من وجود .env وأنه يحتوي على المفتاح
cat NootaBackend/.env | grep GEMINI_API_KEY

# أو عيّن المتغير مباشرة
export GEMINI_API_KEY=your_key_here
```

### ❌ خطأ: "Port 5001 is already in use"
```bash
# أوقف العملية القديمة
lsof -i :5001
kill -9 <PID>

# أو استخدم port مختلفة
PORT=5002 npm start
```

### ❌ خطأ: "Cannot find module 'express'"
```bash
# أعد تثبيت المتطلبات
rm -rf node_modules package-lock.json
npm install
```

### ❌ XTTS Server لا يعمل
```bash
# تأكد من Python 3.8+
python3 --version

# تثبيت المتطلبات
pip install -r requirements_xtts.txt

# شغّل الخادم
python xtts_server.py
```

---

## 🚀 الإطلاق للإنتاج

### في بيئة الإنتاج:

```bash
# عيّن المتغيرات
export NODE_ENV=production
export LOG_LEVEL=error
export PORT=5001

# استخدم PM2 للإدارة
npm install -g pm2
pm2 start src/index.js --name "noota-backend"
pm2 save
pm2 startup
```

### Docker (اختياري)
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY src ./src
EXPOSE 5001
CMD ["npm", "start"]
```

```bash
# البناء والتشغيل
docker build -t noota-backend .
docker run -p 5001:5001 --env-file .env noota-backend
```

---

## 📊 المراقبة والتسجيل

### فعّل التسجيل المفصل
```bash
LOG_LEVEL=debug npm start
```

### عرض السجلات
```bash
# آخر 100 سطر
tail -100 logs/app.log

# بحث عن الأخطاء
grep ERROR logs/app.log
```

---

## 🔄 التحديثات

### تحديث المتطلبات
```bash
npm update
npm audit fix
```

### فحص الإصدارات
```bash
npm outdated
```

---

## 📞 الدعم

- **مستندات Gemini:** https://ai.google.dev/docs
- **Firebase Admin SDK:** https://firebase.google.com/docs/admin/setup
- **XTTS Project:** https://github.com/coqui-ai/TTS

**آخر تحديث:** December 16, 2025
