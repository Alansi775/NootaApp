// Noota/Models/ChatDisplayMessage.swift (ملف جديد)
import Foundation

struct ChatDisplayMessage: Identifiable, Equatable {
    let id: String // هو نفسه id الرسالة الأصلية من Firestore
    let senderID: String
    let originalText: String
    let originalLanguageCode: String
    let timestamp: Date
    var displayText: String // النص الذي سيتم عرضه (الأصلي أو المترجم)
    var isTranslating: Bool = false // هل ما زلنا ننتظر الترجمة؟
    var translationError: String? // لتخزين أي أخطاء في الترجمة

    // يمكنك إضافة initializer لتحويل ChatMessage إلى ChatDisplayMessage
    init(from chatMessage: ChatMessage) {
        self.id = chatMessage.id ?? UUID().uuidString // تأكد من وجود ID
        self.senderID = chatMessage.senderUID
        self.originalText = chatMessage.originalText
        self.originalLanguageCode = chatMessage.originalLanguageCode
        self.timestamp = chatMessage.timestamp // تحويل Timestamp إلى Date
        self.displayText = chatMessage.originalText // نبدأ بالنص الأصلي
    }
}
