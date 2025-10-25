import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import Speech
import AVFoundation

class ConversationViewModel: ObservableObject {
    @Published var room: Room
    @Published var currentUser: User
    @Published var opponentUser: User
    
    @Published var selectedLanguage: String
    @Published var opponentLanguage: String?
    
    @Published var isRecording: Bool = false
    @Published var displayedMessage: String?
    @Published var speechStatusText: String = "Tap to start conversation..."
    @Published var errorMessage: ErrorAlert?
    @Published var liveRecognizedText: String = ""
    
    // ✅ إضافة مؤشرات للنظام المستمر
    @Published var isContinuousMode: Bool = false
    @Published var totalMessagesSent: Int = 0
    @Published var lastSentMessage: String = ""
    @Published var connectionStatus: String = "Ready"
    
    let firestoreService: FirestoreService
    let authService: AuthService
    var speechManager: SpeechManager
    var translationService: TranslationService
    var textToSpeechService: TextToSpeechService
    
    private var cancellables = Set<AnyCancellable>()
    private var messagesListener: ListenerRegistration?
    private var roomListener: ListenerRegistration?
    
    // ✅ متغيرات لإدارة الرسائل المرسلة
    private var sentMessagesHistory: Set<String> = []
    private var messageQueue: [String] = []
    private var isProcessingQueue = false

    let supportedLanguages: [String: String] = [
        "English": "en-US",
        "العربية": "ar-SA",
        "Türkçe": "tr-TR",
        "Español": "es-ES",
        "Français": "fr-FR",
        "Deutsch": "de-DE",
        "Italiano": "it-IT",
        "Português": "pt-BR",
        "Русский": "ru-RU",
        "日本語": "ja-JP",
        "简体中文": "zh-CN",
        "한국어": "ko-KR"
    ]
    
    init(room: Room, currentUser: User, opponentUser: User, firestoreService: FirestoreService, authService: AuthService, speechManager: SpeechManager, translationService: TranslationService, textToSpeechService: TextToSpeechService) {
        self.room = room
        self.currentUser = currentUser
        self.opponentUser = opponentUser
        self.firestoreService = firestoreService
        self.authService = authService
        self.speechManager = speechManager
        self.translationService = translationService
        self.textToSpeechService = textToSpeechService
        
        self.selectedLanguage = currentUser.preferredLanguageCode ?? "en-US"
        self.opponentLanguage = room.participantLanguages?[opponentUser.uid]
        
        setupSpeechManagerBindings()
        
        Logger.log("ConversationViewModel initialized for room: \(room.id ?? "N/A")", level: .info)
        Logger.log("Current user: \(currentUser.username ?? "N/A"), Lang: \(selectedLanguage)", level: .info)
        Logger.log("Opponent user: \(opponentUser.username ?? "N/A"), Lang: \(opponentLanguage ?? "N/A")", level: .info)
    }
    
    func onAppear() {
        setupRoomListener()
        setupMessagesListener()
        
        Task { @MainActor in
            await updateMyLanguageInRoom(languageCode: selectedLanguage)
        }
        Logger.log("ConversationViewModel onAppear called.", level: .info)
    }
    
    func onDisappear() {
        speechManager.stopContinuousRecording()
        speechManager.reset()
        messagesListener?.remove()
        roomListener?.remove()
        cancellables.forEach { $0.cancel() }
        textToSpeechService.stopSpeaking()
        isContinuousMode = false
        Logger.log("ConversationViewModel onDisappear called, cleaned up resources.", level: .info)
    }
    
    private func setupSpeechManagerBindings() {
        // ✅ ربط حالة التسجيل
        speechManager.$isRecording
            .sink { [weak self] recording in
                self?.isRecording = recording
                if recording {
                    self?.connectionStatus = "Listening..."
                } else if self?.isContinuousMode == true {
                    self?.connectionStatus = "Processing..."
                } else {
                    self?.connectionStatus = "Ready"
                }
            }
            .store(in: &cancellables)
            
        // ✅ الاستماع للجمل المكتملة من النظام الجديد
        speechManager.completedSentencePublisher
            .filter { !$0.isEmpty }
            .removeDuplicates()
            .sink { [weak self] completedSentence in
                guard let self = self else { return }
                
                Logger.log("Received completed sentence: '\(completedSentence)'", level: .info)
                
                // ✅ إضافة الرسالة إلى طابور المعالجة
                self.addToMessageQueue(completedSentence)
            }
            .store(in: &cancellables)
            
        // ✅ النص المباشر - للعرض فقط
        speechManager.$liveRecognizedText
            .sink { [weak self] liveText in
                guard let self = self else { return }
                self.liveRecognizedText = liveText
                
                if self.isContinuousMode && !liveText.isEmpty {
                    self.speechStatusText = "Speaking..."
                } else if self.isContinuousMode {
                    self.speechStatusText = "Listening..."
                } else {
                    self.speechStatusText = "Tap to start conversation..."
                }
            }
            .store(in: &cancellables)

        // ✅ معالجة الأخطاء (بدون إيقاف النظام المستمر)
        speechManager.$error
            .compactMap { $0 }
            .sink { [weak self] error in
                guard let self = self else { return }
                
                Logger.log("SpeechManager Warning: \(error.localizedDescription)", level: .warning)
                
                // ✅ لا نعرض رسائل خطأ للمستخدم في النظام المستمر
                if !self.isContinuousMode {
                    self.errorMessage = ErrorAlert(message: error.localizedDescription)
                    self.speechStatusText = "Error: \(error.localizedDescription)"
                }
                
                // ✅ تنظيف الخطأ بعد فترة قصيرة
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.speechManager.error = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // ✅ إضافة رسالة إلى طابور المعالجة
    private func addToMessageQueue(_ message: String) {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // **ملاحظة:** يجب أن تكون آلية اكتشاف الرسائل المكررة أقوى، ربما باستخدام توقيت مؤقت.
        guard !cleanMessage.isEmpty && !sentMessagesHistory.contains(cleanMessage) else {
            Logger.log("Skipping duplicate or empty message: '\(cleanMessage)'", level: .debug)
            return
        }
        
        messageQueue.append(cleanMessage)
        // ✅ نستخدم هذا السجل المؤقت لمنع المعالجة المزدوجة لجملة واحدة
        sentMessagesHistory.insert(cleanMessage)
        // ✅ تنظيف سجل الرسائل المرسلة بمرور الوقت لمنع الازدحام
        if sentMessagesHistory.count > 50 { sentMessagesHistory.removeAll() }
        processMessageQueue()
    }
    
    // ✅ معالجة طابور الرسائل
    private func processMessageQueue() {
        guard !isProcessingQueue && !messageQueue.isEmpty else { return }
        
        isProcessingQueue = true
        let messageToSend = messageQueue.removeFirst()
        
        Task { @MainActor in
            await sendOriginalMessage(text: messageToSend, languageCode: selectedLanguage)
            
            // ✅ انتظار قصير بين الرسائل
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 ثانية
            
            isProcessingQueue = false
            
            // ✅ معالجة الرسالة التالية إذا كانت موجودة
            if !messageQueue.isEmpty {
                processMessageQueue()
            }
        }
    }
    
    private func setupRoomListener() {
        guard let roomID = room.id else {
            Logger.log("Cannot setup room listener: Room ID is nil.", level: .error)
            return
        }

        roomListener = firestoreService.listenToRoom(roomID: roomID) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedRoom):
                    self.room = updatedRoom
                    Logger.log("Room updated from Firestore via listener: \(updatedRoom.id ?? "N/A"), Status: \(updatedRoom.status.rawValue)", level: .info)
                    
                    if let myLang = updatedRoom.participantLanguages?[self.currentUser.uid], self.selectedLanguage != myLang {
                        self.selectedLanguage = myLang
                        self.currentUser.preferredLanguageCode = myLang
                        Logger.log("My language updated from Firestore room doc to: \(myLang)", level: .info)
                    }
                    
                    if let languages = updatedRoom.participantLanguages,
                       let oppLang = languages[self.opponentUser.uid], self.opponentLanguage != oppLang {
                        self.opponentLanguage = oppLang
                        Logger.log("Opponent language updated to: \(oppLang) from Firestore room doc.", level: .info)
                    }
                    
                case .failure(let error):
                    Logger.log("Error listening to room updates: \(error.localizedDescription)", level: .error)
                    if !self.isContinuousMode {
                        self.errorMessage = ErrorAlert(message: "Failed to listen to room: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func setupMessagesListener() {
        guard let roomID = room.id else {
            Logger.log("Cannot setup messages listener: Room ID is nil.", level: .error)
            return
        }

        messagesListener?.remove()

        messagesListener = Firestore.firestore().collection("rooms").document(roomID).collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                guard let self = self else { return }

                if let error = error {
                    Logger.log("Error getting messages: \(error.localizedDescription)", level: .error)
                    if !self.isContinuousMode {
                        self.errorMessage = ErrorAlert(message: "Failed to load messages: \(error.localizedDescription)")
                    }
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    Logger.log("No messages available.", level: .info)
                    return
                }

                if let latestDocument = documents.first {
                    do {
                        let message = try latestDocument.data(as: ChatMessage.self)

                        if message.senderUID != self.currentUser.uid {
                            // ✅ الرسالة موجهة إليّ، يجب أن تكون الترجمة هي النص الذي سأتلقاه
                            let textToSpeak = message.translatedText ?? message.text
                            
                            Logger.log("Received new message from opponent: \(textToSpeak)", level: .info)
                            self.displayedMessage = textToSpeak // ✅ لعرض الترجمة على الشاشة
                            self.connectionStatus = "Message received"
                            
                            // ✅ استخدام لغة الترجمة المستهدفة للـ TTS
                            self.textToSpeechService.speak(text: textToSpeak, languageCode: message.targetLanguageCode)
                            
                            // ✅ إعادة ضبط الحالة بعد قليل
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                if self.isContinuousMode {
                                    self.connectionStatus = "Listening..."
                                }
                            }
                        } else {
                            // رسالتي أنا، تم إرسالها للتو
                            Logger.log("Received my own message: \(message.text)", level: .info)
                            self.lastSentMessage = message.originalText // ✅ عرض النص الأصلي الذي تحدثت به
                            self.totalMessagesSent += 1
                            self.connectionStatus = "Message sent"
                            self.displayedMessage = nil
                            self.liveRecognizedText = ""
                        }
                    } catch {
                        Logger.log("Error decoding message: \(error.localizedDescription)", level: .error)
                        if !self.isContinuousMode {
                            self.errorMessage = ErrorAlert(message: "Failed to decode message: \(error.localizedDescription)")
                        }
                    }
                }
            }
    }
    
    // ✅ تعديل وظيفة toggleRecording
    func toggleContinuousRecording() {
        if isContinuousMode {
            speechManager.stopContinuousRecording()
            isContinuousMode = false
            speechStatusText = "Tap to start conversation..."
            connectionStatus = "Ready"
            liveRecognizedText = ""
            // ✅ معالجة آخر جملة في البافر قبل الإيقاف
            speechManager.stopRecording()
        } else {
            displayedMessage = nil
            liveRecognizedText = ""
            isContinuousMode = true
            speechManager.startContinuousRecording(languageCode: selectedLanguage)
            speechStatusText = "Listening..."
            connectionStatus = "Connected"
            // ✅ إعادة تعيين السجل عند بدء محادثة جديدة
            sentMessagesHistory.removeAll()
            messageQueue.removeAll()
            isProcessingQueue = false
        }
    }
    
    @MainActor
    // ⚠️ تم تغيير هذه الدالة لتقوم بالترجمة أولاً
    func sendOriginalMessage(text: String, languageCode: String) async {
        guard let roomID = room.id else {
            Logger.log("Failed to get roomID for sending message.", level: .error)
            return
        }
        
        guard !text.isEmpty else {
            Logger.log("Not sending empty message.", level: .info)
            return
        }
        
        let targetLangCode = otherParticipantLanguageCode()
        
        // 1. الترجمة باستخدام TranslationService
        self.speechStatusText = "Translating..."
        Logger.log("Starting translation for: '\(text)' from \(languageCode) to \(targetLangCode)", level: .info)
        
        var translatedText: String? = nil
        
        do {
            // ✅ استدعاء الترجمة عبر TranslationService (يجب أن تكون هذه الدالة موجودة)
            translatedText = try await translationService.translate(
                text: text,
                sourceLanguage: languageCode, // 💡 تم تغيير from: إلى sourceLanguage:
                targetLanguage: targetLangCode // 💡 تم تغيير to: إلى targetLanguage:
            )
            Logger.log("Translation complete: '\(translatedText ?? "N/A")'", level: .info)

        } catch {
            Logger.log("Translation failed: \(error.localizedDescription). Sending original text instead.", level: .error)
            // إذا فشلت الترجمة، نرسل النص الأصلي
            translatedText = text
        }
        
        // 2. إعداد الرسالة (نرسل الترجمة في حقل .text والنص الأصلي في .originalText)
        let messageText = translatedText ?? text

        let newMessage = ChatMessage(
            id: UUID().uuidString,
            senderUID: currentUser.uid,
            text: messageText, // ✅ هذا هو النص الذي سيتم عرضه للطرف الآخر/قراءته (الترجمة)
            originalLanguageCode: languageCode,
            timestamp: Date(),
            originalText: text, // ✅ النص الأصلي للمرسل
            translatedText: translatedText, // ✅ الترجمة (مفيدة للسجلات)
            targetLanguageCode: targetLangCode, // ✅ لغة الترجمة
            senderPreferredVoiceGender: currentUser.preferredVoiceGender ?? VoiceGender.default.rawValue
        )
        
        // 3. إرسال الرسالة
        do {
            try await firestoreService.addMessageToRoom(roomID: roomID, message: newMessage)
            Logger.log("Final message (Original: \(text), Translated: \(messageText)) sent to Firestore.", level: .info)
            self.speechStatusText = "Message sent."
        } catch {
            Logger.log("Error sending message to Firestore: \(error.localizedDescription)", level: .error)
            self.errorMessage = ErrorAlert(message: "Failed to send message: \(error.localizedDescription)")
            self.speechStatusText = "Failed to send message."
        }
    }
    
    @MainActor
    func updateMyLanguageInRoom(languageCode: String) async {
        guard let roomID = room.id else {
            Logger.log("Failed to get roomID for language update.", level: .error)
            return
        }

        self.selectedLanguage = languageCode
        self.currentUser.preferredLanguageCode = languageCode
        Logger.log("Attempting to update selectedLanguage locally to: \(languageCode) and currentUser.preferredLanguageCode", level: .debug)

        do {
            try await firestoreService.updateUserPreferredLanguage(userID: currentUser.uid, languageCode: languageCode)
            Logger.log("✅ Successfully updated user's preferred language in Firestore (user doc) to: \(languageCode)", level: .info)
        } catch {
            Logger.log("❌ ERROR updating user's preferred language in Firestore (user doc): \(error.localizedDescription)", level: .error)
            self.errorMessage = ErrorAlert(message: "Failed to save preferred language: \(error.localizedDescription)")
        }

        if room.participantLanguages == nil {
            room.participantLanguages = [:]
        }
        room.participantLanguages?[currentUser.uid] = languageCode
        Logger.log("Attempting to update room participantLanguages locally for \(currentUser.uid) to: \(languageCode)", level: .debug)

        await firestoreService.updateRoomParticipantLanguage(roomID: roomID, userID: currentUser.uid, languageCode: languageCode)
        Logger.log("✅ Successfully attempted to update participant language in Firestore (room doc) to: \(languageCode)", level: .info)
    }
    
    @MainActor
    func leaveRoom() async {
        Logger.log("Attempting to leave room: \(room.id ?? "N/A")", level: .info)
        guard let roomID = room.id else {
            Logger.log("Failed to leave room: Room ID is nil.", level: .error)
            return
        }

        do {
            try await firestoreService.leaveRoom(roomID: roomID, participantUserID: currentUser.uid)
            Logger.log("User \(currentUser.uid) has successfully left and the room was processed.", level: .info)
            onDisappear()

        } catch {
            Logger.log("Error leaving room: \(error.localizedDescription)", level: .error)
            self.errorMessage = ErrorAlert(message: "Failed to leave conversation: \(error.localizedDescription)")
        }
    }
    
    // ⚠️ تم حذف هذه الدالة
    // @MainActor
    // private func translateText(_ text: String, sourceLanguageCode: String, targetLanguageCode: String) async -> String? {
    //     return nil
    // }

    private func otherParticipantLanguageCode() -> String {
        if let opponentUID = room.participantUIDs.first(where: { $0 != currentUser.uid }),
           let opponentLang = room.participantLanguages?[opponentUID] {
            return opponentLang
        }
        // قيمة افتراضية في حالة عدم وجود خصم أو لغة محددة (يجب أن يحدث هذا نادراً)
        return opponentUser.preferredLanguageCode ?? "en-US"
    }
}

// تعريف ChatMessage و ErrorAlert (كما هي لديك)
struct ChatMessage: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    let senderUID: String
    let text: String // ✅ هذا هو نص الترجمة أو النص الأصلي في حالة الفشل
    let originalLanguageCode: String
    let timestamp: Date
    let originalText: String
    let translatedText: String? // ✅ الترجمة الفعلية
    let targetLanguageCode: String
    let senderPreferredVoiceGender: String
}

struct ErrorAlert: Identifiable {
    let id = UUID()
    let message: String
}
