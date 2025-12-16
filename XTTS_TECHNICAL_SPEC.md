# 🏗️ XTTS v2 Integration Technical Specification
## تفاصيل تقنية شاملة للتكامل مع نموذج XTTS v2

---

## 📌 نقطة الانطلاق

**الحالة الحالية:**
- ✅ التطبيق يعمل بشكل مثالي
- ✅ نظام الرسائل مستقر
- ✅ الترجمة تعمل (Google Cloud Translation API)
- ❌ **المشكلة الحالية**: الرسائل المترجمة نص فقط، لا يوجد صوت
- ❌ **المشكلة الثانية**: الصوت المُنتج لا يحافظ على صوت المتحدث الأصلي

**الحل المقترح:**
- استبدال نموذج TTS العام بـ **XTTS v2** المتقدم
- الحفاظ على **خصائص صوت المتحدث الأصلي**
- توليد صوت بجودة عالية **لكل لغة مدعومة** في نفس الوقت

---

## 🔧 متطلبات Backend

### **الخادم المقترح:**
```
خيار 1: Python + Flask/FastAPI (موصى به)
├─ TTS.ai library (XTTS v2)
├─ google-cloud-translate
├─ firebase-admin
├─ pydub (معالجة الصوت)
└─ numpy/scipy (معالجة رياضية)

خيار 2: Node.js + Express
├─ TTS external API
├─ google-cloud-translate
├─ firebase-admin
├─ fluent-ffmpeg
└─ librosa.js
```

### **المتطلبات الحسابية:**
```
الحد الأدنى:
- CPU: 4 cores
- RAM: 8GB
- GPU: اختيارية (يسرع المعالجة 10x)

الموصى به للإنتاج:
- CPU: 8+ cores
- RAM: 16GB+
- GPU: NVIDIA (CUDA supported)
- Storage: 50GB للنموذج + ملفات مؤقتة
```

---

## 🛠️ معمارية Backend

### **الهيكل:**

```
backend/
├─ app.py (تطبيق Flask/FastAPI الرئيسي)
├─ models/
│  ├─ tts_engine.py (محرك XTTS v2)
│  ├─ translator.py (ترجمة النص)
│  └─ voice_processor.py (معالجة الصوت)
├─ services/
│  ├─ firestore_service.py (قاعدة البيانات)
│  ├─ storage_service.py (تخزين الملفات)
│  └─ firebase_auth.py (المصادقة)
├─ routes/
│  ├─ messages.py (معالجة الرسائل)
│  ├─ rooms.py (إدارة الغرف)
│  └─ health.py (فحص صحة الخادم)
├─ config/
│  ├─ settings.py (إعدادات البيئة)
│  └─ credentials.json (مفاتيح Firebase)
├─ utils/
│  ├─ logging.py (تسجيل الأحداث)
│  ├─ cache.py (ذاكرة التخزين المؤقت)
│  └─ helpers.py (دوال مساعدة)
└─ requirements.txt
```

---

## 📋 API Endpoints المطلوبة

### **1. معالجة رسالة جديدة**

```
POST /api/messages/process
Content-Type: application/json

REQUEST:
{
  "messageId": "msg_12345",
  "roomId": "room_abc123",
  "senderUID": "user_1",
  "senderLanguage": "ar-SA",
  "senderVoiceGender": "Male",
  "originalText": "السلام عليكم ورحمة الله",
  "originalAudioUrl": "gs://bucket/rooms/room_abc123/audio/sender_msg_12345.wav",
  "targetLanguages": ["en-US", "es-ES", "tr-TR"],
  "roomLanguages": {
    "user_1": "ar-SA",
    "user_2": "en-US",
    "user_3": "es-ES",
    "user_4": "tr-TR"
  }
}

RESPONSE:
{
  "status": "success",
  "messageId": "msg_12345",
  "processingTime": 12.5,
  "translations": {
    "en-US": "Peace be upon you and God's mercy",
    "es-ES": "La paz sea contigo",
    "tr-TR": "Sana sizin üzerinizde olsun"
  },
  "audioUrls": {
    "ar-SA": "gs://bucket/rooms/room_abc123/messages/msg_12345/ar-SA.wav",
    "en-US": "gs://bucket/rooms/room_abc123/messages/msg_12345/en-US.wav",
    "es-ES": "gs://bucket/rooms/room_abc123/messages/msg_12345/es-ES.wav",
    "tr-TR": "gs://bucket/rooms/room_abc123/messages/msg_12345/tr-TR.wav"
  },
  "duration": {
    "ar-SA": 4.2,
    "en-US": 5.1,
    "es-ES": 4.8,
    "tr-TR": 4.5
  }
}
```

### **2. استخراج عينة الصوت**

```
POST /api/voices/extract-sample
Content-Type: application/json

REQUEST:
{
  "userId": "user_1",
  "audioUrl": "gs://bucket/rooms/room_abc123/audio/sender_msg_12345.wav",
  "startTime": 0,
  "duration": 10  // 10 seconds sample
}

RESPONSE:
{
  "status": "success",
  "userId": "user_1",
  "sampleStored": true,
  "samplePath": "gs://bucket/voice_samples/user_1/sample.wav",
  "voiceCharacteristics": {
    "gender": "male",
    "speed": "normal",
    "emotion": "neutral"
  }
}
```

### **3. فحص حالة المعالجة**

```
GET /api/messages/{messageId}/status

RESPONSE:
{
  "messageId": "msg_12345",
  "status": "completed" | "processing" | "failed",
  "progress": 85,  // percentage
  "startTime": "2024-12-11T10:30:00Z",
  "completedTime": "2024-12-11T10:30:15Z",
  "error": null
}
```

---

## 💻 الكود الأساسي للـ Backend (Python)

### **ملف: tts_engine.py**

```python
import torch
from TTS.api import TTS
import numpy as np
from scipy.io import wavfile
import logging

logger = logging.getLogger(__name__)

class XTTSEngine:
    def __init__(self):
        """تهيئة نموذج XTTS v2"""
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        logger.info(f"Initializing XTTS v2 on {self.device}")
        
        self.tts = TTS(
            model_name="tts_models/multilingual/multi-dataset/xtts_v2",
            gpu=(self.device == "cuda"),
            progress_bar=False
        )
        
        self.supported_languages = {
            "en-US": "en",
            "ar-SA": "ar",
            "es-ES": "es",
            "fr-FR": "fr",
            "de-DE": "de",
            "it-IT": "it",
            "pt-BR": "pt",
            "ru-RU": "ru",
            "tr-TR": "tr",
            "ja-JP": "ja",
            "zh-CN": "zh-cn",
            "ko-KR": "ko"
        }
        
        self.voice_samples = {}  # {user_id: speaker_wav_path}

    def extract_voice_sample(self, audio_path, user_id, duration=10):
        """
        استخراج عينة نظيفة من صوت المستخدم
        
        Args:
            audio_path: مسار الملف الصوتي
            user_id: معرف المستخدم
            duration: مدة العينة بالثواني
            
        Returns:
            path to saved sample
        """
        try:
            # تحميل الملف الصوتي
            sample_rate, audio_data = wavfile.read(audio_path)
            
            # استخراج أول 'duration' ثانية
            end_sample = sample_rate * duration
            audio_sample = audio_data[:int(end_sample)]
            
            # حفظ العينة
            sample_path = f"voice_samples/{user_id}/sample.wav"
            wavfile.write(sample_path, sample_rate, audio_sample)
            
            # تخزين في الذاكرة
            self.voice_samples[user_id] = sample_path
            
            logger.info(f"✅ Voice sample extracted for user {user_id}")
            return sample_path
            
        except Exception as e:
            logger.error(f"❌ Error extracting voice sample: {e}")
            raise

    def synthesize_multilingual(self, text, speaker_wav, target_languages):
        """
        توليد صوت للنص بعدة لغات
        
        Args:
            text: النص المراد تحويله
            speaker_wav: مسار عينة الصوت الأصلي
            target_languages: قائمة رموز اللغات (مثل ["en", "es", "ar"])
            
        Returns:
            dict: {language: audio_array}
        """
        results = {}
        
        logger.info(f"🎤 Synthesizing for {len(target_languages)} languages")
        
        for lang_code, lang in zip(target_languages, 
                                   [self.supported_languages.get(lc, lc) 
                                    for lc in target_languages]):
            try:
                logger.info(f"Processing {lang_code}...")
                
                # توليد الصوت
                wav = self.tts.tts(
                    text=text,
                    speaker_wav=speaker_wav,
                    language=lang
                )
                
                results[lang_code] = wav
                logger.info(f"✅ {lang_code} completed")
                
            except Exception as e:
                logger.error(f"❌ Error synthesizing {lang_code}: {e}")
                results[lang_code] = None
        
        return results

    def save_audio_files(self, audio_dict, output_dir):
        """
        حفظ ملفات صوتية متعددة
        
        Args:
            audio_dict: {language: audio_array}
            output_dir: مجلد الحفظ
            
        Returns:
            dict: {language: file_path}
        """
        saved_files = {}
        
        for lang, audio in audio_dict.items():
            if audio is None:
                continue
                
            file_path = f"{output_dir}/{lang}.wav"
            wavfile.write(file_path, 22050, np.array(audio))
            saved_files[lang] = file_path
            logger.info(f"💾 Saved {lang} to {file_path}")
        
        return saved_files
```

### **ملف: translator.py**

```python
from google.cloud import translate_v2
import logging

logger = logging.getLogger(__name__)

class Translator:
    def __init__(self, project_id):
        """تهيئة Google Cloud Translation"""
        self.client = translate_v2.Client(project_id=project_id)
        
    def translate_text(self, text, source_language, target_language):
        """
        ترجمة نص من لغة إلى أخرى
        
        Args:
            text: النص المراد ترجمته
            source_language: كود اللغة الأصلية (مثل "ar")
            target_language: كود اللغة المستهدفة (مثل "en")
            
        Returns:
            الكود المترجم
        """
        try:
            result = self.client.translate_text(
                text=text,
                source_language=source_language,
                target_language=target_language
            )
            translated = result['translatedText']
            logger.info(f"✅ Translated {source_language} → {target_language}")
            return translated
            
        except Exception as e:
            logger.error(f"❌ Translation error: {e}")
            raise

    def translate_to_multiple(self, text, source_language, target_languages):
        """
        ترجمة نص إلى عدة لغات بكفاءة
        
        Args:
            text: النص
            source_language: اللغة الأصلية
            target_languages: قائمة اللغات المستهدفة
            
        Returns:
            dict: {language: translated_text}
        """
        translations = {}
        
        for target_lang in target_languages:
            try:
                translated = self.translate_text(
                    text, 
                    source_language, 
                    target_lang
                )
                translations[target_lang] = translated
                
            except Exception as e:
                logger.error(f"Failed to translate to {target_lang}: {e}")
                translations[target_lang] = text  # fallback to original
        
        return translations
```

### **ملف: app.py (API الرئيسي)**

```python
from flask import Flask, request, jsonify
from firebase_admin import credentials, initialize_app, firestore, storage
import logging
from datetime import datetime
from tts_engine import XTTSEngine
from translator import Translator

app = Flask(__name__)
logger = logging.getLogger(__name__)

# تهيئة Firebase
cred = credentials.Certificate("config/credentials.json")
initialize_app(cred, {
    'storageBucket': 'your-project.appspot.com'
})
db = firestore.client()
bucket = storage.bucket()

# تهيئة محركات المعالجة
tts_engine = XTTSEngine()
translator = Translator(project_id="your-project-id")

@app.route('/api/messages/process', methods=['POST'])
def process_message():
    """معالجة رسالة جديدة وتوليد ترجمات + صوت"""
    try:
        data = request.json
        message_id = data['messageId']
        room_id = data['roomId']
        sender_uid = data['senderUID']
        original_text = data['originalText']
        original_language = data['senderLanguage']
        target_languages = data['targetLanguages']
        original_audio_url = data['originalAudioUrl']
        
        start_time = datetime.now()
        logger.info(f"🔄 Processing message {message_id}")
        
        # الخطوة 1: استخراج عينة الصوت من الملف الأصلي
        logger.info("Step 1: Extracting voice sample...")
        local_audio = download_file(original_audio_url)
        voice_sample_path = tts_engine.extract_voice_sample(
            local_audio, 
            sender_uid
        )
        
        # الخطوة 2: ترجمة النص إلى جميع اللغات
        logger.info(f"Step 2: Translating to {len(target_languages)} languages...")
        lang_codes = [original_language.split('-')[0].lower()] + \
                     [l.split('-')[0].lower() for l in target_languages]
        target_lang_codes = [l.split('-')[0].lower() for l in target_languages]
        
        translations = translator.translate_to_multiple(
            original_text,
            lang_codes[0],
            target_lang_codes
        )
        
        # الخطوة 3: توليد صوت لكل ترجمة
        logger.info("Step 3: Synthesizing audio for each language...")
        audio_dict = tts_engine.synthesize_multilingual(
            text=original_text,  # الرسالة الأصلية
            speaker_wav=voice_sample_path,
            target_languages=target_languages
        )
        
        # إضافة الملف الصوتي الأصلي
        audio_dict[original_language] = local_audio
        
        # الخطوة 4: حفظ الملفات على Firebase Storage
        logger.info("Step 4: Uploading to Firebase Storage...")
        storage_path = f"rooms/{room_id}/messages/{message_id}"
        audio_urls = {}
        
        for lang, audio_path in tts_engine.save_audio_files(
            audio_dict, 
            f"temp/{message_id}"
        ).items():
            if audio_path:
                blob_path = f"{storage_path}/{lang}.wav"
                blob = bucket.blob(blob_path)
                blob.upload_from_filename(audio_path)
                audio_urls[lang] = f"gs://bucket/{blob_path}"
        
        # الخطوة 5: تحديث Firestore
        logger.info("Step 5: Updating Firestore...")
        processing_time = (datetime.now() - start_time).total_seconds()
        
        db.collection("rooms").document(room_id).collection("messages")\
            .document(message_id).update({
                "translations": translations,
                "audioUrls": audio_urls,
                "processingStatus": "completed",
                "processingTime": processing_time,
                "processedAt": datetime.now()
            })
        
        logger.info(f"✅ Message {message_id} processed in {processing_time:.2f}s")
        
        return jsonify({
            "status": "success",
            "messageId": message_id,
            "processingTime": processing_time,
            "translations": translations,
            "audioUrls": audio_urls
        }), 200
        
    except Exception as e:
        logger.error(f"❌ Error processing message: {e}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

def download_file(url):
    """تنزيل ملف من Firebase Storage"""
    # Implementation here
    pass

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=False)
```

---

## 🔄 تدفق معالجة الرسالة الكامل

```
1️⃣ المستخدم يرسل رسالة
   ↓
2️⃣ التطبيق يحفظ الرسالة في Firestore
   ↓
3️⃣ يُرسل webhook إلى Backend
   ↓
4️⃣ Backend يستقبل الرسالة
   ├─ استخراج عينة الصوت
   ├─ ترجمة النص لجميع اللغات
   ├─ توليد صوت لكل لغة
   ├─ حفظ الملفات
   └─ تحديث Firestore
   ↓
5️⃣ Firestore Listener يُنبه التطبيقات
   ↓
6️⃣ كل مستخدم يستقبل:
   ├─ النص المترجم (بلغته)
   ├─ الملف الصوتي (بلغته)
   └─ تشغيل فوري
```

---

## 🚀 خطة النشر (Deployment)

### **الخيار 1: Google Cloud Run**
```bash
# بناء صورة Docker
docker build -t noota-backend .

# نشر على Cloud Run
gcloud run deploy noota-backend \
  --image gcr.io/project/noota-backend \
  --memory 4Gi \
  --cpu 2 \
  --timeout 300
```

### **الخيار 2: AWS EC2**
```bash
# تثبيت المتطلبات
pip install -r requirements.txt

# تشغيل الخادم
python app.py
```

### **الخيار 3: Heroku**
```bash
git push heroku main
```

---

## ✅ قائمة الفحص النهائية

- [ ] تثبيت جميع المكتبات المطلوبة
- [ ] اختبار XTTS v2 محلياً
- [ ] اختبار الترجمة (Google Cloud API)
- [ ] إعداد Firebase Credentials
- [ ] نشر Backend على الخادم
- [ ] اختبار جميع API Endpoints
- [ ] اختبار مع عدة لغات
- [ ] قياس الأداء والتأخير
- [ ] اختبار مع أجهزة متعددة
- [ ] مراقبة الأخطاء والتسجيل

---

**هذا الملف سيُرسل إلى Gemini لتقديم الملاحظات والتحسينات**

