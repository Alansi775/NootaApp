# 🎙️ Noota - Real-Time Multilingual Conversation App

**A real-time voice translation app built with SwiftUI, Firebase, and Gemini AI**

## 📋 المحتويات (Table of Contents)

- [نظرة عامة](#-نظرة-عامة)
- [المتطلبات](#-المتطلبات)
- [التثبيت والإعداد](#-التثبيت-والإعداد)
- [تشغيل المشروع](#-تشغيل-المشروع)
- [البنية المعمارية](#-البنية-المعمارية)
- [الميزات](#-الميزات)
- [استكشاف الأخطاء](#-استكشاف-الأخطاء)

---

## 🎯 نظرة عامة

**Noota** تطبيق للمحادثات الحية بين شخصين بلغات مختلفة. يقوم بـ:
- ✅ التعرف على الكلام بشكل مستمر
- ✅ ترجمة فورية باستخدام Gemini AI
- ✅ عرض الترجمات في الوقت الفعلي
- ✅ مزامنة البيانات عبر Firebase
- ✅ دعم لغات متعددة (English, العربية)

---

## 💻 المتطلبات

### للتطوير على الجهاز:
- **Xcode 14.0+** (مع iOS 15.0+)
- **CocoaPods** أو **Swift Package Manager**
- **Node.js 16+** (للبيئة الخلفية - Backend)
- **Python 3.8+** (للخوادم المتخصصة)
- حساب **Firebase** مع Firestore
- مفتاح **Google Gemini API**

### الملفات المطلوبة:
```
Noota/
├── GoogleService-Info.plist  ← Firebase config (ضروري!)
└── [باقي الملفات]
```

---

## 🚀 التثبيت والإعداد

### 1️⃣ استنساخ المشروع

```bash
git clone https://github.com/Alansi775/NootaApp.git
cd NootaApp
```

### 2️⃣ إعداد Firebase

**خطوات في Firebase Console:**
1. اذهب إلى [firebase.google.com](https://firebase.google.com)
2. أنشئ مشروع جديد (أو استخدم موجود)
3. أضف تطبيق iOS:
   - Bundle ID: `com.noota.app`
   - Download `GoogleService-Info.plist`
4. ضع الملف في: `Noota/GoogleService-Info.plist`
5. فعّل **Firestore Database** (في وضع الاختبار)
6. فعّل **Authentication** (Anonymous & Email/Password)

### 3️⃣ إعداد Gemini API

```bash
# احصل على المفتاح من Google AI Studio
# https://aistudio.google.com/app/apikeys

# ضعه في GeminiService.swift
# البحث عن: let apiKey = "YOUR_API_KEY_HERE"
```

### 4️⃣ إعداد البيئة الخلفية (Backend)

#### خادم الترجمة الرئيسي (Node.js):

```bash
cd NootaBackend
npm install

# أنشئ ملف .env
cat > .env << EOF
PORT=5001
GEMINI_API_KEY=your_gemini_key_here
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_PRIVATE_KEY="your_firebase_key"
FIREBASE_CLIENT_EMAIL=your_firebase_email
EOF

# ابدأ الخادم
npm start
```

**المتوقع:**
```
✅ Server running on http://localhost:5001
✅ Firebase connected
✅ Ready for connections
```

#### خادم XTTS (نطق صوتي - اختياري):

```bash
cd NootaBackend

# تثبيت المتطلبات
pip install -r requirements_xtts.txt

# تشغيل الخادم
python xtts_server.py
```

**الخادم سيعمل على:** `http://localhost:5002`

---

## 📱 تشغيل المشروع

### في Xcode:

```bash
# 1. فتح المشروع
open Noota.xcodeproj

# أو للـ Workspace (إذا كنت تستخدم CocoaPods)
open Noota.xcworkspace
```

### الخطوات في Xcode:

1. **اختر الجهاز** أو **Simulator**
2. **Product → Run** (أو اضغط `Cmd + R`)
3. **شغّل البيئة الخلفية أولاً** (Backend)
4. **تأكد من اتصال الشبكة**

### التشغيل من Terminal:

```bash
# تجميع فقط
xcodebuild build -scheme Noota -configuration Debug

# تجميع وتشغيل
xcodebuild test -scheme Noota
```

---

## 🏗️ البنية المعمارية

### الأمام (iOS App):

```
Noota/
├── Managers/
│   ├── SpeechManager.swift          ← التعرف على الكلام
│   └── AppRootManager.swift         ← إدارة التطبيق
├── Services/
│   ├── FirestoreService.swift       ← Firebase Firestore
│   ├── AuthService.swift            ← المصادقة
│   ├── GeminiService.swift          ← ترجمة AI
│   ├── TranslationService.swift     ← معالجة الترجمة
│   └── TextToSpeechService.swift    ← النطق الصوتي
├── ViewModels/
│   ├── ConversationViewModel.swift  ← منطق المحادثة
│   ├── PairingViewModel.swift       ← ربط المستخدمين
│   └── RoomViewModel.swift          ← إدارة الغرفة
├── Views/
│   ├── ConversationView.swift       ← واجهة المحادثة
│   ├── AuthView.swift               ← تسجيل الدخول
│   ├── PairingView.swift            ← ربط المستخدمين
│   └── QRCodeScannerView.swift      ← ماسح QR
└── Models/
    ├── Message.swift                ← هيكل الرسالة
    ├── Room.swift                   ← هيكل الغرفة
    ├── User.swift                   ← هيكل المستخدم
    └── Language.swift               ← اللغات المدعومة
```

### الخلف (Backend):

```
NootaBackend/
├── src/
│   ├── index.js                     ← نقطة الدخول
│   ├── services/
│   │   ├── translationService.js
│   │   ├── audioService.js
│   │   └── geminiService.js
│   └── routes/
│       ├── translation.js
│       └── audio.js
├── xtts_server.py                   ← خادم النطق (اختياري)
├── requirements_xtts.txt
├── package.json
└── .env                             ← متغيرات البيئة
```

---

## ✨ الميزات الرئيسية

### 1️⃣ التعرف على الكلام المستمر
- نظام مستمر بدون انقطاع
- دعم لغات متعددة
- حفظ تسجيلات الصوت

### 2️⃣ الترجمة الفورية
- استخدام Gemini AI للترجمة
- معالجة متوازية
- سرعة عالية

### 3️⃣ إدارة الغرف والمستخدمين
- ربط بين مستخدمين عبر QR Code
- مزامنة فورية عبر Firebase
- دعم جلسات متعددة

### 4️⃣ واجهة المستخدم
- تصميم حديث مع SwiftUI
- عرض ترجمات حية
- إشعارات فورية

---

## 🔧 استكشاف الأخطاء

### ❌ المشروع لا يجمّع (Won't Compile)

```bash
# نظّف البناء
xcodebuild clean -scheme Noota

# احذف DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# أعد التثبيت
pod install  # إذا استخدمت CocoaPods
```

### ❌ لا يوجد اتصال بـ Firebase

✅ **الحل:**
1. تأكد من وجود `GoogleService-Info.plist` في المجلد الصحيح
2. تحقق من Bundle ID في Xcode
3. أعد تحميل الملف من Firebase Console

### ❌ خطأ في الترجمة (Translation Error)

✅ **الحل:**
1. تأكد من مفتاح Gemini API الصحيح
2. تحقق من حد استخدام الـ API (quotas)
3. شغّل Backend على `localhost:5001`

### ❌ Simulator لا يعترف بالميكروفون

✅ **الحل:**
```
Hardware → Microphone → On
```

### ❌ البيانات لا تتزامن بين الجهازين

✅ **الحل:**
1. تأكد من أن كلا الجهازين على نفس الشبكة
2. استخدم نفس Firebase Project
3. تحقق من قواعد Firestore Security Rules

---

## 📊 الإعدادات الموصى بها

### في الإنتاج (Production):

```javascript
// NootaBackend/.env
NODE_ENV=production
PORT=5001
HTTPS=true
RATE_LIMIT=100  // طلبات في الدقيقة
LOG_LEVEL=error
```

### في Firebase Security Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /rooms/{roomId} {
      allow read, write: if request.auth != null;
    }
    match /messages/{messageId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
    }
  }
}
```

---

## 📞 الدعم والمساعدة

### الملفات الإضافية:
- `QUICK_START.md` - دليل البدء السريع
- `PROJECT_OVERVIEW.md` - نظرة عامة على المشروع
- `SYSTEM_ARCHITECTURE_AR.md` - البنية المعمارية بالعربية
- `iOS_INTEGRATION_GUIDE.md` - دليل التكامل مع iOS

### المشاكل الشائعة:
اطلع على ملف `FIX_FREEZE_ISSUE.md` إذا واجهت تجميد الواجهة

---

## 📜 الرخصة

MIT License - انظر LICENSE.md

---

## 👨‍💻 المساهمون

- **Mohammed Saleh** - المطور الرئيسي
- Community contributions welcome! 🎉

---

**آخر تحديث:** December 16, 2025  
**إصدار المشروع:** 2.0.0-beta

🚀 **ابدأ الآن وابني محادثات بلا حدود!**
