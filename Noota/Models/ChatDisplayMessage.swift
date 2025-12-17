// Noota/Models/ChatDisplayMessage.swift (ملف جديد)
import Foundation

struct ChatDisplayMessage: Identifiable, Equatable {
    let id: String
    let senderID: String
    let senderName: String
    let originalText: String
    let originalLanguageCode: String
    let timestamp: Date
    var displayText: String
    var translatedText: String?
    var targetLanguageCode: String?
    
    //  CHUNKS SUPPORT - Multiple texts with matching audio
    var translatedChunks: [String]? // ["Hello", "My name is", "Mohammed"]
    var audioUrls: [String]? // ["url1", "url2", "url3"] - matched by index!
    var audioBuffers: [Data]? // Local cache of audio data
    var currentChunkPlaying: Int = -1 // Which chunk is currently playing
    
    var audioUrl: String?
    var audioBuffer: Data?
    var isTranslating: Bool = false
    var processingStatus: String?
    var translationError: String?

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
