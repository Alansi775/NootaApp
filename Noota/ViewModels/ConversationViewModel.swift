import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import Speech
import AVFoundation

// 🔧 Message for display
struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let timestamp: Date
}

// 🔧 AnyCodable helper to decode mixed type JSON responses
enum AnyCodable: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

class ConversationViewModel: ObservableObject {
    @Published var room: Room
    @Published var currentUser: User
    @Published var opponentUser: User
    
    @Published var selectedLanguage: String
    @Published var opponentLanguage: String?
    
    @Published var isRecording: Bool = false
    @Published var displayedMessages: [ChatMessage] = []
    @Published var speechStatusText: String = "Tap to start conversation..."
    @Published var errorMessage: ErrorAlert?
    @Published var liveRecognizedText: String = ""
    
    @Published var isContinuousMode: Bool = false
    @Published var connectionStatus: String = "Ready"
    
    let firestoreService: FirestoreService
    let authService: AuthService
    var speechManager: SpeechManager
    var translationService: TranslationService
    var textToSpeechService: TextToSpeechService
    
    private var cancellables = Set<AnyCancellable>()
    private var messagesListener: ListenerRegistration?
    private var roomListener: ListenerRegistration?
    
    private var sentMessagesHistory: Set<String> = []
    private var messageQueue: [String] = []
    private var isProcessingQueue = false
    private var displayedMessageIDs: Set<String> = []

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
        Logger.log("🛑 onDisappear called, cleaning up...", level: .info)
        
        speechManager.stopContinuousRecording()
        speechManager.reset()
        
        messagesListener?.remove()
        messagesListener = nil
        Logger.log("✅ Messages listener removed", level: .info)
        
        roomListener?.remove()
        roomListener = nil
        Logger.log("✅ Room listener removed", level: .info)
        
        cancellables.forEach { $0.cancel() }
        textToSpeechService.stopSpeaking()
        
        displayedMessageIDs.removeAll()
        Logger.log("✅ Displayed messages cache cleared", level: .debug)
        
        isContinuousMode = false
        Logger.log("✅ ConversationViewModel cleaned up completely", level: .info)
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
        
        guard !cleanMessage.isEmpty && !sentMessagesHistory.contains(cleanMessage) else {
            Logger.log("Skipping duplicate or empty message: '\(cleanMessage)'", level: .debug)
            return
        }
        
        messageQueue.append(cleanMessage)
        sentMessagesHistory.insert(cleanMessage)
        
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
            
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 ثانية
            
            isProcessingQueue = false
            
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
                    Logger.log("🔄 Room updated from Firestore via listener: \(updatedRoom.id ?? "N/A"), Status: \(updatedRoom.status.rawValue)", level: .info)
                    
                    // ✅ إذا أصبحت الغرفة 'ended'، المستخدم الآخر يخرج
                    if updatedRoom.status == .ended {
                        Logger.log("⚠️ Room status changed to 'ended'. Another user left. Auto-exiting...", level: .warning)
                        Task { @MainActor in
                            self.errorMessage = ErrorAlert(message: "Your conversation partner has left the room.")
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                            await self.leaveRoom()
                        }
                    }
                    
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
                    Logger.log("❌ Error listening to room updates: \(error.localizedDescription)", level: .error)
                    if !self.isContinuousMode {
                        self.errorMessage = ErrorAlert(message: "Failed to listen to room: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func setupMessagesListener() {
        guard let roomID = room.id else {
            Logger.log("❌ Cannot setup messages listener: Room ID is nil.", level: .error)
            return
        }

        messagesListener?.remove()
        
        Logger.log("🎧 Setting up messages listener for room: \(roomID)", level: .info)

        messagesListener = Firestore.firestore()
            .collection("rooms")
            .document(roomID)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("❌ Listener error: \(error.localizedDescription)", level: .error)
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // معالجة التغييرات بدون blocking
                for change in snapshot.documentChanges {
                    if change.type == .added || change.type == .modified {
                        do {
                            var message = try change.document.data(as: Message.self)
                            message.id = change.document.documentID
                            
                            // تخطي رسائلي
                            if message.senderUID == self.currentUser.uid { continue }
                            
                            // تخطي بدون ترجمة
                            if message.translations == nil || message.translations?.isEmpty == true { continue }
                            
                            // تخطي المعروضة
                            if let msgID = message.id, self.displayedMessageIDs.contains(msgID) { continue }
                            
                            // عرّض الرسالة الجديدة
                            self.displayNewMessage(message)
                            
                        } catch {
                            Logger.log("❌ Decode error: \(error.localizedDescription)", level: .error)
                        }
                    }
                }
            }
        
        Logger.log("✅ Listener ready", level: .info)
    }
    
    private func displayNewMessage(_ message: Message) {
        var displayText = message.originalText
        
        if let translations = message.translations,
           let myLanguageTranslations = translations[self.selectedLanguage],
           !myLanguageTranslations.isEmpty {
            displayText = myLanguageTranslations.joined(separator: " ")
        } else if let translations = message.translations, !translations.isEmpty,
                  let firstTranslation = translations.values.first {
            displayText = firstTranslation.joined(separator: " ")
        }
        
        // تحديث الـ UI على الـ Main Thread فقط
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let messageID = message.id ?? UUID().uuidString
            if !self.displayedMessageIDs.contains(messageID) {
                let chatMessage = ChatMessage(
                    id: messageID,
                    text: displayText,
                    timestamp: Date()
                )
                
                // ✅ الحل: استبدل القائمة بالرسالة الجديدة فقط
                self.displayedMessages = [chatMessage]
                self.displayedMessageIDs.insert(messageID)
                
                Logger.log("✅ Message displayed: \(messageID)", level: .info)
            }
        }
    }
    
    func toggleContinuousRecording() {
        if isContinuousMode {
            let audioURL = speechManager.stopAudioRecording()
            
            speechManager.stopContinuousRecording()
            isContinuousMode = false
            speechStatusText = "Tap to start conversation..."
            connectionStatus = "Ready"
            liveRecognizedText = ""
            
            if let audioURL = audioURL {
                Logger.log("✅ Recording file ready: \(audioURL.lastPathComponent)", level: .info)
            }
            
            speechManager.stopRecording()
        } else {
            displayedMessages.removeAll()
            liveRecognizedText = ""
            isContinuousMode = true
            
            speechManager.startAudioRecording()
            speechManager.startContinuousRecording(languageCode: selectedLanguage)
            speechStatusText = "Listening..."
            connectionStatus = "Connected"
            
            sentMessagesHistory.removeAll()
            messageQueue.removeAll()
            isProcessingQueue = false
        }
    }
    
    @MainActor
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
        
        self.speechStatusText = "Sending..."
        Logger.log("Sending original text: '\(text)' from \(languageCode) to Backend", level: .info)
        
        let audioURL = speechManager.stopAudioRecording()
        
        do {
            let backendURL = "http://Mustafa-iMac.local:5001/api/messages/create"
            
            var request = URLRequest(url: URL(string: backendURL)!)
            request.httpMethod = "POST"
            request.timeoutInterval = 60.0
            
            let boundary = UUID().uuidString
            var body = Data()
            
            // Add text fields
            let fields = [
                "roomID": roomID,
                "senderUID": currentUser.uid,
                "originalText": text,
                "originalLanguageCode": languageCode,
                "targetLanguageCode": targetLangCode
            ]
            
            for (key, value) in fields {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
            
            // Add audio file if available
            if let audioURL = audioURL {
                do {
                    let audioData = try Data(contentsOf: audioURL)
                    body.append("--\(boundary)\r\n".data(using: .utf8)!)
                    body.append("Content-Disposition: form-data; name=\"audioFile\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
                    body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
                    body.append(audioData)
                    body.append("\r\n".data(using: .utf8)!)
                    
                    Logger.log("📤 Audio file attached: \(audioData.count) bytes", level: .info)
                } catch {
                    Logger.log("⚠️ Warning: Could not attach audio file: \(error.localizedDescription)", level: .warning)
                }
            } else {
                Logger.log("⚠️ Warning: No audio file available", level: .warning)
            }
            
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            
            // 📤 Send to Backend
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "InvalidResponse", code: -1, userInfo: nil)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            
            let response_data = try JSONDecoder().decode([String: AnyCodable].self, from: data)
            let messageID = response_data["messageID"]?.stringValue ?? "unknown"
            
            Logger.log("✅ Message sent to Backend successfully (ID: \(messageID))", level: .info)
            self.speechStatusText = "Message sent"
            
            // ✅ مسح الـ buffer فوراً عشان نبدأ نستمع للجملة الجديدة
            // بدون تأخير لأن الإرسال اتمّ بنجاح
            self.speechManager.clearRecognitionBuffer()
            
            // Clean up audio file
            if let audioURL = audioURL {
                try? FileManager.default.removeItem(at: audioURL)
                Logger.log("🗑️ Cleaned up audio file", level: .debug)
            }
            
        } catch {
            Logger.log("❌ Error sending message to Backend: \(error.localizedDescription)", level: .error)
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
        Logger.log("🚪 Attempting to leave room: \(room.id ?? "N/A")", level: .info)
        guard let roomID = room.id else {
            Logger.log("❌ Failed to leave room: Room ID is nil.", level: .error)
            return
        }

        do {
            Logger.log("📤 Sending leave signal to Firestore...", level: .info)
            try await firestoreService.leaveRoom(roomID: roomID, participantUserID: currentUser.uid)
            Logger.log("✅ User \(currentUser.uid) has successfully left the room.", level: .info)
            
            // تأخير قليل للسماح للمستخدمين الآخرين بمعالجة الخروج
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            Logger.log("🧹 Cleaning up local resources...", level: .info)
            onDisappear()

        } catch {
            Logger.log("❌ Error leaving room: \(error.localizedDescription)", level: .error)
            self.errorMessage = ErrorAlert(message: "Failed to leave conversation: \(error.localizedDescription)")
        }
    }
    
    private func otherParticipantLanguageCode() -> String {
        if let opponentUID = room.participantUIDs.first(where: { $0 != currentUser.uid }),
           let opponentLang = room.participantLanguages?[opponentUID] {
            return opponentLang
        }
        return opponentUser.preferredLanguageCode ?? "en-US"
    }
}


struct ErrorAlert: Identifiable {
    let id = UUID()
    let message: String
}
