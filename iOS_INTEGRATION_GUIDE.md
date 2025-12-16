# 📱 Noota iOS App - XTTS v2 Integration Guide
## دليل التعديلات المطلوبة في تطبيق iOS

---

## 📋 ملخص التعديلات

سيتم تعديل التطبيق الحالي **بحد أدنى** من التغييرات لأن النظام يعمل بشكل مثالي بالفعل. التعديلات ستكون:

| المكون | التغيير | السبب |
|--------|--------|-------|
| **ConversationViewModel** | إضافة معالج للرسائل الجديدة مع صوت | استقبال الملفات الصوتية |
| **ChatBubbleView** | إضافة زر تشغيل صوتي | تشغيل الملفات الصوتية |
| **TextToSpeechService** | تحديث لتشغيل الملفات الصوتية | بدلاً من إنشاء صوت جديد |
| **FirestoreService** | إضافة listener للحقول الجديدة | الاستماع لـ audioUrls |
| **Message Model** | إضافة حقول الترجمة والصوت | تخزين البيانات الجديدة |

---

## 🔧 التعديلات التفصيلية

### **1. تحديث نموذج Message**

**الملف:** `Noota/Models/Message.swift`

```swift
struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    let senderUID: String
    let text: String // النص الأصلي
    let originalLanguageCode: String
    let timestamp: Date
    let originalText: String
    let targetLanguageCode: String
    let senderPreferredVoiceGender: String
    
    // ✨ الحقول الجديدة لـ XTTS
    let translations: [String: String]?  // مثال: {"en-US": "Hello", "es-ES": "Hola"}
    let audioUrls: [String: String]?     // مثال: {"en-US": "gs://...", "es-ES": "gs://..."}
    let processingStatus: String?         // "processing" | "completed" | "failed"
    let processingTime: Double?           // الوقت بالثواني
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderUID
        case text
        case originalLanguageCode
        case timestamp
        case originalText
        case targetLanguageCode
        case senderPreferredVoiceGender
        case translations
        case audioUrls
        case processingStatus
        case processingTime
    }
}
```

---

### **2. تحديث TextToSpeechService**

**الملف:** `Noota/Services/TextToSpeechService.swift`

```swift
import Foundation
import AVFoundation

class TextToSpeechService: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    @Published var isSpeaking = false
    
    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }
    
    // ✨ الدالة الجديدة: تشغيل ملف صوتي من Firebase Storage
    func playRemoteAudio(from url: String, languageCode: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let audioURL = URL(string: url) else {
                    Logger.log("Invalid audio URL: \(url)", level: .error)
                    return
                }
                
                // تنزيل الملف الصوتي
                let (data, response) = try URLSession.shared.data(from: audioURL)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    Logger.log("Failed to download audio: \(url)", level: .error)
                    return
                }
                
                // تشغيل الملف الصوتي
                DispatchQueue.main.async {
                    self.playAudioData(data, languageCode: languageCode)
                }
                
            } catch {
                Logger.log("Error downloading audio: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    // ✨ الدالة الجديدة: تشغيل بيانات الصوت
    private func playAudioData(_ audioData: Data, languageCode: String) {
        do {
            self.audioPlayer = try AVAudioPlayer(data: audioData, fileTypeHint: .wav)
            self.audioPlayer?.delegate = self
            
            DispatchQueue.main.async {
                self.isSpeaking = true
            }
            
            self.audioPlayer?.play()
            Logger.log("Playing audio for language: \(languageCode)", level: .info)
            
        } catch {
            Logger.log("Error playing audio: \(error.localizedDescription)", level: .error)
            DispatchQueue.main.async {
                self.isSpeaking = false
            }
        }
    }
    
    // الدالة الأصلية: النطق النصي (مازالت موجودة للتوافقية)
    func speak(text: String, languageCode: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = 0.5
        
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
        
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
```

---

### **3. تحديث ChatBubbleView**

**الملف:** `Noota/Views/ChatBubbleView.swift`

```swift
import SwiftUI

struct ChatBubbleView: View {
    let message: ChatDisplayMessage
    @ObservedObject var textToSpeechService: TextToSpeechService
    @State private var isPlayingAudio = false
    @State private var showTranslation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ✨ عرض النص الأصلي
            Text(message.originalText)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            // ✨ عرض النص المترجم (إذا توفر)
            if let translatedText = message.translatedText, showTranslation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Translation (\(getLanguageName(message.targetLanguageCode))):")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(translatedText)
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
            }
            
            // ✨ أزرار التحكم
            HStack(spacing: 8) {
                // زر التشغيل الصوتي
                if let audioUrl = message.audioUrl {
                    Button(action: {
                        if isPlayingAudio {
                            textToSpeechService.stopSpeaking()
                            isPlayingAudio = false
                        } else {
                            playAudio(audioUrl)
                        }
                    }) {
                        Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
                
                // زر عرض الترجمة
                if message.translatedText != nil {
                    Button(action: {
                        withAnimation {
                            showTranslation.toggle()
                        }
                    }) {
                        Image(systemName: showTranslation ? "book.fill" : "book")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // عرض الوقت والمتحدث
                VStack(alignment: .trailing, spacing: 2) {
                    Text(message.senderName)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(message.isFromCurrentUser ? Color.blue : Color.gray)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private func playAudio(_ audioUrl: String) {
        isPlayingAudio = true
        textToSpeechService.playRemoteAudio(from: audioUrl, languageCode: message.targetLanguageCode)
        
        // إيقاف التشغيل بعد انتهاء الملف
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if isPlayingAudio {
                isPlayingAudio = false
            }
        }
    }
    
    private func getLanguageName(_ code: String) -> String {
        let languages: [String: String] = [
            "en-US": "English",
            "ar-SA": "العربية",
            "es-ES": "Español",
            "fr-FR": "Français",
            "de-DE": "Deutsch",
            "it-IT": "Italiano",
            "pt-BR": "Português",
            "ru-RU": "Русский",
            "tr-TR": "Türkçe",
            "ja-JP": "日本語",
            "zh-CN": "简体中文",
            "ko-KR": "한국어"
        ]
        return languages[code] ?? code
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// ✨ نموذج البيانات المحدث
struct ChatDisplayMessage: Identifiable, Equatable {
    let id: String
    let senderName: String
    let senderUID: String
    let originalText: String
    let translatedText: String?
    let audioUrl: String?
    let targetLanguageCode: String
    let timestamp: Date
    let isFromCurrentUser: Bool
}
```

---

### **4. تحديث ConversationViewModel**

**الملف:** `Noota/ViewModels/ConversationViewModel.swift` (إضافات فقط)

```swift
private func setupMessagesListener() {
    let roomID = room.id ?? ""
    
    messagesListener = firestoreService.listenToMessages(
        roomID: roomID
    ) { [weak self] fetchedMessages, error in
        guard let self = self else { return }
        
        if let error = error {
            Logger.log("Error listening to messages: \(error.localizedDescription)", level: .error)
            return
        }
        
        DispatchQueue.main.async {
            // ✨ معالجة الرسائل الجديدة
            for chatMessage in fetchedMessages {
                self.processChatMessage(chatMessage)
            }
        }
    }
}

// ✨ الدالة الجديدة: معالجة الرسالة وتحويلها لـ ChatDisplayMessage
private func processChatMessage(_ chatMessage: ChatMessage) {
    // التحقق من أن الرسالة لم تُعالج من قبل
    let messageKey = "\(chatMessage.senderUID)_\(chatMessage.timestamp)"
    if sentMessagesHistory.contains(messageKey) {
        return
    }
    
    sentMessagesHistory.insert(messageKey)
    
    // الحصول على اسم المرسل
    let senderName = (chatMessage.senderUID == currentUser.uid) 
        ? currentUser.username ?? "You"
        : opponentUser.username ?? "User"
    
    // ✨ تحديد الرابط الصوتي الصحيح بناءً على لغة المستخدم الحالي
    var audioUrl: String? = nil
    
    if let audioUrls = chatMessage.audioUrls,
       let url = audioUrls[selectedLanguage] ?? audioUrls.values.first {
        audioUrl = url
    }
    
    // إنشاء ChatDisplayMessage
    let displayMessage = ChatDisplayMessage(
        id: chatMessage.id ?? UUID().uuidString,
        senderName: senderName,
        senderUID: chatMessage.senderUID,
        originalText: chatMessage.originalText,
        translatedText: chatMessage.translatedText,
        audioUrl: audioUrl,
        targetLanguageCode: selectedLanguage,
        timestamp: chatMessage.timestamp,
        isFromCurrentUser: chatMessage.senderUID == currentUser.uid
    )
    
    // إضافة الرسالة لقائمة الرسائل المعروضة
    DispatchQueue.main.async {
        if !self.displayedMessages.contains(displayMessage) {
            self.displayedMessages.append(displayMessage)
        }
    }
    
    // ✨ تشغيل الصوت تلقائياً إذا كان متوفراً
    if let audioUrl = audioUrl, chatMessage.processingStatus == "completed" {
        Task {
            await self.playReceivedAudio(audioUrl)
        }
    }
}

// ✨ الدالة الجديدة: تشغيل الصوت المستقبل
private func playReceivedAudio(_ audioUrl: String) async {
    DispatchQueue.main.async {
        self.textToSpeechService.playRemoteAudio(
            from: audioUrl,
            languageCode: self.selectedLanguage
        )
    }
}

// ✨ تحديث عند استقبال رسالة جديدة
@Published var displayedMessages: [ChatDisplayMessage] = []
```

---

### **5. تحديث FirestoreService**

**الملف:** `Noota/Services/FirestoreService.swift` (إضافات)

```swift
// ✨ تحديث الدالة listenToMessages لاستقبال الحقول الجديدة
func listenToMessages(roomID: String, completion: @escaping ([ChatMessage], Error?) -> Void) -> ListenerRegistration {
    return db.collection("rooms").document(roomID).collection("messages")
        .order(by: "timestamp", descending: false)
        .addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion([], error)
                return
            }
            let fetchedMessages = querySnapshot?.documents.compactMap { document -> ChatMessage? in
                do {
                    var message = try document.data(as: ChatMessage.self)
                    
                    // ✨ التأكد من قراءة جميع الحقول الجديدة
                    let data = document.data()
                    if let translations = data["translations"] as? [String: String] {
                        message.translatedText = translations.values.first
                    }
                    if let audioUrls = data["audioUrls"] as? [String: String] {
                        // audioUrls متوفر الآن
                    }
                    if let processingStatus = data["processingStatus"] as? String {
                        message.processingStatus = processingStatus
                    }
                    
                    return message
                } catch {
                    Logger.log("Error decoding message: \(error)", level: .error)
                    return nil
                }
            } ?? []
            completion(fetchedMessages, nil)
        }
}
```

---

## 🔄 تدفق البيانات الجديد

```
┌─────────────────────────────────────────┐
│        مستخدم يرسل رسالة                │
└───────────────────┬─────────────────────┘
                    │
        ┌───────────▼──────────────┐
        │ 1. حفظ الرسالة الأصلية  │
        │ 2. إرسال الصوت الأصلي   │
        │ 3. تحديث Firebase      │
        └───────────┬──────────────┘
                    │
        ┌───────────▼──────────────────────┐
        │   Backend معالجة (XTTS v2)      │
        │ 1. ترجمة النص                  │
        │ 2. توليد صوت بكل لغة           │
        │ 3. حفظ الملفات الصوتية         │
        │ 4. تحديث Firestore            │
        └───────────┬──────────────────────┘
                    │
        ┌───────────▼──────────────────────┐
        │   Firestore Listener            │
        │ (جميع المستخدمين الآخرين)      │
        └───────────┬──────────────────────┘
                    │
        ┌───────────▼──────────────────────┐
        │  iOS App استقبل الرسالة الجديدة │
        │ 1. معالجة Firestore documents   │
        │ 2. اختيار الملف الصوتي بلغتك  │
        │ 3. عرض الرسالة + الترجمة      │
        │ 4. تشغيل الصوت تلقائياً       │
        └───────────────────────────────────┘
```

---

## ✅ التعديلات ملخص سريع

| الملف | التغيير | الأسطر |
|------|--------|--------|
| `Message.swift` | إضافة حقول translations, audioUrls | +5 حقول |
| `TextToSpeechService.swift` | إضافة playRemoteAudio() | +30 سطر |
| `ChatBubbleView.swift` | إضافة زر التشغيل الصوتي | +50 سطر |
| `ConversationViewModel.swift` | إضافة processChatMessage() | +40 سطر |
| `FirestoreService.swift` | تحديث listenToMessages() | +10 أسطر |

---

## 🚀 خطوات التنفيذ

1. **تحديث نموذج Message** - إضافة الحقول الجديدة
2. **تحديث TextToSpeechService** - دعم تشغيل الملفات الصوتية
3. **تحديث ChatBubbleView** - عرض الأزرار الجديدة
4. **تحديث ConversationViewModel** - معالجة البيانات الجديدة
5. **اختبار محلي** - التأكد من عمل كل شيء
6. **نشر Backend** - تشغيل خادم المعالجة
7. **اختبار النهاية إلى النهاية** - اختبار سيناريو كامل

---

## 🎯 النتيجة النهائية

✅ **قبل:** رسائل نصية فقط
✅ **بعد:** رسائل نصية + صوتية بصوت المتحدث الأصلي

---

**هذا الملف يوضح أن التعديلات على iOS ستكون بحد أدنى ومركزة على التكامل فقط**

