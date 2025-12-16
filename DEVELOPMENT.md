# 🛠️ Development Setup Guide - دليل إعداد البيئة

## نظام التشغيل: macOS

---

## ✅ المتطلبات الأساسية

### 1. Xcode و Command Line Tools
```bash
# تثبيت Xcode من App Store (أو الأمر التالي)
xcode-select --install

# التحقق
xcode-select -p
# يجب أن يطبع: /Applications/Xcode.app/Contents/Developer
```

### 2. Homebrew (مدير الحزم)
```bash
# تثبيت
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# التحقق
brew --version
```

### 3. Node.js و npm
```bash
# تثبيت عبر Homebrew
brew install node

# التحقق
node --version    # يجب أن يكون 16+
npm --version     # يجب أن يكون 7+
```

### 4. Python 3
```bash
# تثبيت
brew install python3

# التحقق
python3 --version  # يجب أن يكون 3.8+
```

### 5. Git
```bash
# يأتي مع Xcode، لكن تحقق
git --version
```

---

## 🚀 البدء السريع (5 دقائق)

```bash
# 1. استنسخ المشروع
git clone https://github.com/Alansi775/NootaApp.git
cd NootaApp

# 2. أعدّ كل شيء
./setup.sh all-setup

# 3. ملء متغيرات البيئة
# - ضع GoogleService-Info.plist في Noota/
# - عيّن GEMINI_API_KEY في NootaBackend/.env

# 4. شغّل البيئة الخلفية
./setup.sh backend-start

# 5. شغّل التطبيق (في نافذة Xcode جديدة)
open Noota.xcworkspace
# اضغط Cmd+R
```

---

## 📱 إعداد iOS

### تثبيت CocoaPods
```bash
# تثبيت
sudo gem install cocoapods

# التحقق
pod repo update
```

### إعداد Firebase
1. اذهب إلى [firebase.google.com](https://firebase.google.com)
2. أنشئ مشروع جديد
3. أضف تطبيق iOS (Bundle ID: `com.noota.app`)
4. حمّل `GoogleService-Info.plist`
5. ضعه في `Noota/GoogleService-Info.plist`

### تثبيت Dependencies iOS
```bash
cd NootaApp
pod install
# سيثبت جميع المتطلبات (Firebase, Combine, إلخ)
```

---

## 🔧 إعداد Backend

### Node.js Packages
```bash
cd NootaBackend
npm install

# المتطلبات الرئيسية:
# - express (إطار العمل)
# - axios (HTTP client)
# - dotenv (متغيرات البيئة)
# - firebase-admin (Firebase SDK)
# - google-generative-ai (Gemini API)
```

### Python Packages (للنطق الصوتي)
```bash
cd NootaBackend

# إنشاء virtual environment
python3 -m venv venv
source venv/bin/activate

# تثبيت المتطلبات
pip install -r requirements_xtts.txt
```

### Gemini API Key
```bash
# احصل على المفتاح من
# https://aistudio.google.com/app/apikeys

# ضعه في NootaBackend/.env
GEMINI_API_KEY=AIzaSy...
```

---

## 🏗️ هيكل المشروع بعد الإعداد

```
NootaApp/
├── .git/                           ← Git repository
├── Noota/
│   ├── GoogleService-Info.plist    ← Firebase config ⭐
│   ├── Managers/
│   ├── Services/
│   ├── Views/
│   └── ViewModels/
├── Noota.xcodeproj/                ← iOS project
├── Noota.xcworkspace/              ← Workspace (استخدم هذا!)
├── NootaBackend/
│   ├── src/
│   ├── node_modules/               ← تثبت تلقائياً
│   ├── venv/                        ← Python environment
│   ├── package.json
│   ├── .env                         ← ملف البيئة ⭐
│   └── SETUP.md
├── README_SETUP.md                 ← التوثيق
├── setup.sh                         ← أداة البناء
└── ...
```

---

## 🎯 قائمة التحقق من الإعداد

- [ ] Xcode مثبت ورصيح
- [ ] Node.js 16+ مثبت
- [ ] Python 3.8+ مثبت
- [ ] CocoaPods مثبت
- [ ] المشروع مستنسخ
- [ ] GoogleService-Info.plist موضوع
- [ ] GEMINI_API_KEY معيّن في .env
- [ ] `npm install` تم تنفيذه في NootaBackend/
- [ ] `pod install` تم تنفيذه في Noota/
- [ ] Backend يعمل على localhost:5001
- [ ] التطبيق يشتغل في Simulator/Device

---

## 🚀 أوامر مفيدة

```bash
# بناء المشروع
./setup.sh ios-build

# اختبار iOS
./setup.sh ios-test

# تشغيل Backend
./setup.sh backend-start

# تشغيل كل شيء
./setup.sh all-start

# تنظيف الملفات المؤقتة
./setup.sh clean

# عرض المساعدة
./setup.sh help
```

---

## 🔍 التحقق من التشغيل

### تطبيق iOS
```bash
# افتح Xcode
open Noota.xcworkspace

# أو اضغط Cmd+R في Xcode
```

### Backend Server
```bash
# افتح نافذة terminal جديدة
cd NootaBackend
npm start

# يجب أن ترى:
# ✅ Server running on http://localhost:5001
# ✅ Firebase connected
# ✅ Gemini API ready
```

### فحص الاتصال
```bash
# من نافذة terminal جديدة
curl http://localhost:5001/health

# يجب أن ترى:
# {"status":"ok","uptime":...}
```

---

## ⚠️ مشاكل شائعة

### "Pods configuration invalid"
```bash
cd Noota
pod install --repo-update
```

### "Port 5001 already in use"
```bash
lsof -i :5001
kill -9 <PID>
```

### "Cannot find GoogleService-Info.plist"
```bash
# الملف يجب أن يكون في المسار الصحيح:
Noota/GoogleService-Info.plist

# و يجب أن يكون مضافاً في Xcode
# Xcode → Target Noota → Build Phases → Copy Bundle Resources
```

### "GEMINI_API_KEY is not set"
```bash
# تأكد من NootaBackend/.env
cat NootaBackend/.env | grep GEMINI_API_KEY

# أو عيّن يدويّاً
export GEMINI_API_KEY=your_key_here
```

---

## 💡 نصائح إنتاجية

### إعادة بناء سريعة
```bash
# بدل حذف DerivedData كاملاً
xcodebuild clean -scheme Noota
```

### استخدام Simulator مختلف
```bash
# قائمة الأجهزة
xcrun simctl list devices

# تشغيل simulator معين
xcrun simctl boot "iPhone 15 Pro"
```

### مراقبة الشبكة
```bash
# استخدم Network Link Conditioner لمحاكاة سرعات مختلفة
# تحميل من: https://developer.apple.com/download/all/
```

---

## 🔗 الروابط المهمة

- **Xcode:** https://developer.apple.com/xcode/
- **Firebase Console:** https://console.firebase.google.com
- **Gemini API:** https://ai.google.dev
- **Node.js:** https://nodejs.org/
- **CocoaPods:** https://cocoapods.org/

---

## 📚 المستندات الإضافية

- `README_SETUP.md` - دليل التثبيت الشامل
- `NootaBackend/SETUP.md` - إعداد Backend
- `PROJECT_OVERVIEW.md` - نظرة عامة على المشروع
- `QUICK_START.md` - البدء السريع

---

**آخر تحديث:** December 16, 2025  
**الإصدار:** 2.0.0-beta

احفظ هذا الملف وارجع إليه أثناء التطوير! 🚀
