// Noota/Models/Message.swift
import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    @DocumentID var id: String? // مُعرّف الرسالة من Firestore
    let senderUID: String // UID للمرسل
    let originalText: String // النص الأصلي الذي قاله المرسل
    var translatedText: String? // النص المترجم (يمكن أن يتم ترجمته على جهاز المستقبِل أو المرسل)
    let originalLanguageCode: String // رمز لغة النص الأصلي (مثال: "en", "ar")
    let targetLanguageCode: String // رمز لغة الترجمة (مثال: "en", "ar")
    
    // Voice gender preference of the sender for *receiving* their translation
    // This allows the receiver to play the translation in a voice gender preferred by the sender for their own translated voice.
    let senderPreferredVoiceGender: String // "male" or "female" or "default"

    let timestamp: Date // وقت إرسال الرسالة
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderUID
        case originalText
        case translatedText // ✨ تأكد من وجودها هنا أيضًا لفك تشفيرها
        case originalLanguageCode
        case targetLanguageCode
        case senderPreferredVoiceGender
        case timestamp
    }
    
    // ✨ التعديل هنا: أضف translatedText إلى الـ init المخصص
    init(id: String? = nil, senderUID: String, originalText: String, translatedText: String? = nil, originalLanguageCode: String, targetLanguageCode: String, senderPreferredVoiceGender: String, timestamp: Date = Date()) {
        self.id = id
        self.senderUID = senderUID
        self.originalText = originalText
        self.translatedText = translatedText // ✨ قم بتعيينها
        self.originalLanguageCode = originalLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.senderPreferredVoiceGender = senderPreferredVoiceGender
        self.timestamp = timestamp
    }
}

enum VoiceGender: String, CaseIterable, Codable {
    case male = "male"
    case female = "female"
    case `default` = "default" // If no specific preference
}
