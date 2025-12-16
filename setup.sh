#!/bin/bash

# 🚀 Noota - Build and Run Script
# Usage: ./setup.sh [command]

set -e  # Exit on error

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🎙️  Noota - Setup Script${NC}"
echo "================================"

# الأوامر المتاحة
show_help() {
    cat << EOF
استخدام: ./setup.sh [command]

الأوامر المتاحة:
  ios-setup       إعداد مشروع iOS (تثبيت المتطلبات)
  ios-build       بناء تطبيق iOS
  ios-test        اختبار تطبيق iOS
  backend-setup   إعداد خادم Node.js
  backend-start   تشغيل خادم Node.js
  xtts-start      تشغيل خادم XTTS (النطق الصوتي)
  all-setup       إعداد كل شيء
  all-start       تشغيل كل شيء
  clean           تنظيف الملفات المؤقتة
  help            عرض هذه المساعدة

أمثلة:
  ./setup.sh ios-setup     # إعداد iOS فقط
  ./setup.sh backend-start # تشغيل البيئة الخلفية
  ./setup.sh all-start     # تشغيل كل شيء

EOF
}

# إعداد iOS
setup_ios() {
    echo -e "${YELLOW}📱 إعداد مشروع iOS...${NC}"
    
    # التحقق من Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}❌ Xcode غير مثبت!${NC}"
        exit 1
    fi
    
    # تثبيت CocoaPods إذا لم تكن موجودة
    if ! command -v pod &> /dev/null; then
        echo -e "${YELLOW}⚠️  تثبيت CocoaPods...${NC}"
        sudo gem install cocoapods
    fi
    
    # تثبيت Pod dependencies
    echo -e "${YELLOW}📦 تثبيت Pods...${NC}"
    pod install || pod repo update && pod install
    
    echo -e "${GREEN}✅ تم إعداد iOS بنجاح!${NC}"
    echo -e "${YELLOW}📌 تلميح: استخدم 'Noota.xcworkspace' وليس '.xcodeproj'${NC}"
}

# بناء iOS
build_ios() {
    echo -e "${YELLOW}🏗️  بناء مشروع iOS...${NC}"
    
    if [ ! -f "Noota.xcworkspace/contents.xcworkspacedata" ]; then
        echo -e "${RED}❌ لم يتم العثور على Workspace. شغّل 'ios-setup' أولاً!${NC}"
        exit 1
    fi
    
    xcodebuild build \
        -workspace Noota.xcworkspace \
        -scheme Noota \
        -configuration Debug \
        -destination 'generic/platform=iOS Simulator'
    
    echo -e "${GREEN}✅ تم بناء iOS بنجاح!${NC}"
}

# اختبار iOS
test_ios() {
    echo -e "${YELLOW}🧪 اختبار مشروع iOS...${NC}"
    
    xcodebuild test \
        -workspace Noota.xcworkspace \
        -scheme Noota \
        -destination 'generic/platform=iOS Simulator'
    
    echo -e "${GREEN}✅ انتهت الاختبارات!${NC}"
}

# إعداد Backend
setup_backend() {
    echo -e "${YELLOW}⚙️  إعداد البيئة الخلفية...${NC}"
    
    # التحقق من Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js غير مثبت! قم بتثبيته من nodejs.org${NC}"
        exit 1
    fi
    
    cd NootaBackend
    
    # تثبيت dependencies
    echo -e "${YELLOW}📦 تثبيت npm packages...${NC}"
    npm install
    
    # إنشاء .env إذا لم تكن موجودة
    if [ ! -f ".env" ]; then
        echo -e "${YELLOW}⚙️  إنشاء ملف .env...${NC}"
        cat > .env << EOF
# Backend Configuration
PORT=5001
NODE_ENV=development

# Gemini API
GEMINI_API_KEY=your_api_key_here

# Firebase (اختياري إذا كنت تستخدم Firebase Admin SDK)
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_PRIVATE_KEY="your_private_key"
FIREBASE_CLIENT_EMAIL=your_email@firebase.iam.gserviceaccount.com

# XTTS Server (للنطق الصوتي)
XTTS_URL=http://localhost:5002

# Logging
LOG_LEVEL=info
EOF
        echo -e "${YELLOW}⚠️  تم إنشاء .env - أكمل ملء المفاتيح!${NC}"
    fi
    
    cd ..
    echo -e "${GREEN}✅ تم إعداد Backend بنجاح!${NC}"
}

# تشغيل Backend
start_backend() {
    echo -e "${YELLOW}🚀 تشغيل خادم Node.js...${NC}"
    
    if [ ! -d "NootaBackend/node_modules" ]; then
        echo -e "${YELLOW}📦 لم يتم تثبيت الـ dependencies. جاري التثبيت...${NC}"
        setup_backend
    fi
    
    cd NootaBackend
    npm start
}

# تشغيل XTTS
start_xtts() {
    echo -e "${YELLOW}🎵 تشغيل خادم XTTS...${NC}"
    
    # التحقق من Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}❌ Python 3 غير مثبت!${NC}"
        exit 1
    fi
    
    cd NootaBackend
    
    # تثبيت requirements
    if [ ! -d "venv" ]; then
        echo -e "${YELLOW}📦 إنشاء virtual environment...${NC}"
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements_xtts.txt
    else
        source venv/bin/activate
    fi
    
    python xtts_server.py
}

# إعداد كل شيء
setup_all() {
    echo -e "${YELLOW}🔧 إعداد البيئة الكاملة...${NC}"
    setup_ios
    setup_backend
    echo -e "${GREEN}✅ تم إعداد كل شيء!${NC}"
    echo -e "${YELLOW}📌 الخطوة التالية: ./setup.sh all-start${NC}"
}

# تشغيل كل شيء
start_all() {
    echo -e "${YELLOW}🚀 تشغيل التطبيق الكامل...${NC}"
    
    # شغّل Backend في خيط منفصل
    echo -e "${YELLOW}⚡ تشغيل Backend...${NC}"
    start_backend &
    BACKEND_PID=$!
    
    sleep 3
    
    # افتح Xcode
    echo -e "${YELLOW}📱 فتح Xcode...${NC}"
    open Noota.xcworkspace
    
    echo -e "${GREEN}✅ تم بدء كل شيء!${NC}"
    echo -e "${YELLOW}📌 تلميح: استخدم Cmd+R في Xcode لتشغيل التطبيق${NC}"
}

# تنظيف الملفات المؤقتة
clean() {
    echo -e "${YELLOW}🧹 تنظيف الملفات المؤقتة...${NC}"
    
    # iOS
    rm -rf build/ DerivedData/
    xcodebuild clean -scheme Noota 2>/dev/null || true
    
    # Backend
    cd NootaBackend
    rm -rf node_modules/ dist/
    cd ..
    
    echo -e "${GREEN}✅ تم التنظيف بنجاح!${NC}"
}

# معالجة الأوامر
case "${1:-help}" in
    ios-setup)
        setup_ios
        ;;
    ios-build)
        build_ios
        ;;
    ios-test)
        test_ios
        ;;
    backend-setup)
        setup_backend
        ;;
    backend-start)
        start_backend
        ;;
    xtts-start)
        start_xtts
        ;;
    all-setup)
        setup_all
        ;;
    all-start)
        start_all
        ;;
    clean)
        clean
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}❌ أمر غير معروف: $1${NC}"
        show_help
        exit 1
        ;;
esac

echo -e "${GREEN}✨ تم!${NC}"
