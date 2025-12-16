// Noota/Models/ChatDisplayMessage.swift (ملف جديد)
import Foundation

struct ChatDisplayMessage: Identifiable, Equatable {
    let id: String // هو نفسه id الرسالة الأصلية من Firestore
    let senderID: String
    let senderName: String // اسم المرسل للعرض
    let originalText: String
    let originalLanguageCode: String
    let timestamp: Date
    var displayText: String // النص الذي سيتم عرضه (الأصلي أو المترجم)
    var translatedText: String? // النص المترجم
    var targetLanguageCode: String? // كود اللغة المستهدفة
    var audioUrl: String? // رابط الملف الصوتي المترجم
    var isTranslating: Bool = false // هل ما زلنا ننتظر الترجمة؟
    var processingStatus: String? // "processing" | "completed" | "failed"
    var translationError: String? // لتخزين أي أخطاء في الترجمة

    // يمكنك إضافة initializer لتحويل ChatMessage إلى ChatDisplayMessage
    init(from chatMessage: Message, senderName: String = "Unknown") {
        self.id = chatMessage.id ?? UUID().uuidString // تأكد من وجود ID
        self.senderID = chatMessage.senderUID
        self.senderName = senderName
        self.originalText = chatMessage.originalText
        self.originalLanguageCode = chatMessage.originalLanguageCode
        self.timestamp = chatMessage.timestamp // تحويل Timestamp إلى Date
        self.displayText = chatMessage.originalText // نبدأ بالنص الأصلي
        self.translatedText = chatMessage.translatedText
        self.targetLanguageCode = chatMessage.targetLanguageCode
        // احصل على رابط الصوت للغة المستهدفة
        if let audioUrls = chatMessage.audioUrls,
           let audioArray = audioUrls[chatMessage.targetLanguageCode],
           let firstAudio = audioArray.first,
           firstAudio != nil {
            self.audioUrl = firstAudio
        } else {
            self.audioUrl = nil
        }
        self.processingStatus = chatMessage.processingStatus
    }
}
