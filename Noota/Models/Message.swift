// Noota/Models/Message.swift
import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    var id: String? // مُعرّف الرسالة من Firestore
    let senderUID: String // UID للمرسل
    let originalText: String // النص الأصلي الذي قاله المرسل
    var translatedText: String? // النص المترجم (يمكن أن يتم ترجمته على جهاز المستقبِل أو المرسل)
    let originalLanguageCode: String // رمز لغة النص الأصلي (مثال: "en", "ar")
    let targetLanguageCode: String // رمز لغة الترجمة (مثال: "en", "ar")
    
    // Voice gender preference of the sender for *receiving* their translation
    // This allows the receiver to play the translation in a voice gender preferred by the sender for their own translated voice.
    let senderPreferredVoiceGender: String // "male" or "female" or "default"

    let timestamp: Date // وقت إرسال الرسالة
    
    // ✨ الحقول الجديدة من XTTS v2 Backend - دعم التوليد المتدفق
    var translations: [String: [String]]? // {"tr-TR": ["مرحبا", "كيفك"], ...} - نصوص مترجمة كقطع
    var audioUrls: [String: [String?]]? // {"tr-TR": ["url1", null, "url3"], ...} - روابط صوتية كقطع (قد تحتوي على null)
    var processingStatus: String? // "pending" | "processing" | "partial" | "completed" | "failed"
    var totalChunks: Int? // عدد القطع الكلي
    var processedChunks: Int? // عدد القطع المعالجة حتى الآن
    var originalAudioUrl: String? // رابط الملف الصوتي الأصلي (لاستخدام voice cloning في Backend)
    
    // ✨ التعديل: أضف الحقول الجديدة للـ init مع دعم القطع
    init(id: String? = nil, senderUID: String, originalText: String, translatedText: String? = nil, originalLanguageCode: String, targetLanguageCode: String, senderPreferredVoiceGender: String, timestamp: Date = Date(), translations: [String: [String]]? = nil, audioUrls: [String: [String?]]? = nil, processingStatus: String? = nil, totalChunks: Int? = nil, processedChunks: Int? = nil, originalAudioUrl: String? = nil) {
        self.id = id
        self.senderUID = senderUID
        self.originalText = originalText
        self.translatedText = translatedText
        self.originalLanguageCode = originalLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.senderPreferredVoiceGender = senderPreferredVoiceGender
        self.timestamp = timestamp
        self.translations = translations
        self.audioUrls = audioUrls
        self.processingStatus = processingStatus
        self.totalChunks = totalChunks
        self.processedChunks = processedChunks
        self.originalAudioUrl = originalAudioUrl
    }
    
    // ✨ Custom decoder to handle Firestore decoding properly
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode @DocumentID field
        id = try container.decodeIfPresent(String.self, forKey: .id)
        
        // Decode required fields
        senderUID = try container.decode(String.self, forKey: .senderUID)
        originalText = try container.decode(String.self, forKey: .originalText)
        originalLanguageCode = try container.decode(String.self, forKey: .originalLanguageCode)
        targetLanguageCode = try container.decode(String.self, forKey: .targetLanguageCode)
        senderPreferredVoiceGender = try container.decode(String.self, forKey: .senderPreferredVoiceGender)
        
        // Handle timestamp - can be Timestamp or Date
        if let timestamp = try container.decodeIfPresent(Timestamp.self, forKey: .timestamp) {
            self.timestamp = timestamp.dateValue()
        } else if let timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) {
            self.timestamp = timestamp
        } else {
            self.timestamp = Date()
        }
        
        // Decode optional fields
        translatedText = try container.decodeIfPresent(String.self, forKey: .translatedText)
        
        // Decode translations - try multiple approaches
        do {
            translations = try container.decodeIfPresent([String: [String]].self, forKey: .translations)
        } catch {
            Logger.log(" Error decoding translations from Firestore, trying alternative format", level: .warning)
            translations = nil
        }
        
        audioUrls = try container.decodeIfPresent([String: [String?]].self, forKey: .audioUrls)
        processingStatus = try container.decodeIfPresent(String.self, forKey: .processingStatus)
        totalChunks = try container.decodeIfPresent(Int.self, forKey: .totalChunks)
        processedChunks = try container.decodeIfPresent(Int.self, forKey: .processedChunks)
        originalAudioUrl = try container.decodeIfPresent(String.self, forKey: .originalAudioUrl)
        
        Logger.log(" Message decoded successfully - ID: \(id ?? "nil"), Translations: \(translations?.description ?? "nil")", level: .debug)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(senderUID, forKey: .senderUID)
        try container.encode(originalText, forKey: .originalText)
        try container.encodeIfPresent(translatedText, forKey: .translatedText)
        try container.encode(originalLanguageCode, forKey: .originalLanguageCode)
        try container.encode(targetLanguageCode, forKey: .targetLanguageCode)
        try container.encode(senderPreferredVoiceGender, forKey: .senderPreferredVoiceGender)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(translations, forKey: .translations)
        try container.encodeIfPresent(audioUrls, forKey: .audioUrls)
        try container.encodeIfPresent(processingStatus, forKey: .processingStatus)
        try container.encodeIfPresent(totalChunks, forKey: .totalChunks)
        try container.encodeIfPresent(processedChunks, forKey: .processedChunks)
        try container.encodeIfPresent(originalAudioUrl, forKey: .originalAudioUrl)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderUID
        case originalText
        case translatedText
        case originalLanguageCode
        case targetLanguageCode
        case senderPreferredVoiceGender
        case timestamp
        case translations
        case audioUrls
        case processingStatus
        case totalChunks
        case processedChunks
        case originalAudioUrl
    }
}


enum VoiceGender: String, CaseIterable, Codable {
    case male = "male"
    case female = "female"
    case `default` = "default" // If no specific preference
}
