import Foundation
import Combine
import FirebaseFirestore
import Speech // لاستخدام SpeechManager
import AVFoundation // لـ AVSpeechSynthesizer

// ✨ استيراد TranslationService بعد نقلها لملفها الخاص
// تأكد من أن هذا الاستيراد صحيح بناءً على مسار ملف TranslationService.swift لديك
// إذا كانت في نفس المجلد مثل RoomViewModel، قد لا تحتاج لاستيراد صريح إذا كانت public
// ولكن الأفضل استيرادها بشكل صريح إذا كانت في مجلد مختلف (مثل Noota/Services)
// import Noota.TranslationService // مثال إذا كان NameSpace هو Noota

class RoomViewModel: ObservableObject {
    @Published var roomID: String
    @Published var currentUser: User
    @Published var messages: [Message] = []
    @Published var otherParticipant: User?
    @Published var userLanguageCode: String = "en"
    @Published var hasSelectedLanguage: Bool = false
    @Published var errorMessage: String?
    @Published var canSpeak: Bool = false
    
    let firestoreService: FirestoreService
    let speechManager: SpeechManager // سيتم حقنها
    let translationService: TranslationService // سيتم حقنها
    
    private var cancellables = Set<AnyCancellable>()
    private var messageListener: ListenerRegistration?
    
    @Published var activeSpeakerUID: String?
    
    init(roomID: String, currentUser: User, firestoreService: FirestoreService, speechManager: SpeechManager, translationService: TranslationService) {
        self.roomID = roomID
        self.currentUser = currentUser
        self.firestoreService = firestoreService
        self.speechManager = speechManager
        self.translationService = translationService
        
        // تعيين لغة المستخدم الحالية من المستخدم المحقون
        self.userLanguageCode = currentUser.preferredLanguageCode ?? "en-US" // استخدام الافتراضي إذا لم يكن موجودًا

        firestoreService.$currentFirestoreRoom
            .sink { [weak self] room in
                guard let self = self else { return }
                
                if let room = room, room.id == self.roomID {
                    self.updateParticipants(room: room)
                    self.updateMicrophoneControl(room: room)
                    // تحديث لغة المستخدم الحالي إذا تغيرت في الغرفة (عبر Firebase)
                    if let myLang = room.participantLanguages?[self.currentUser.uid],
                       self.userLanguageCode != myLang {
                        self.userLanguageCode = myLang
                        Logger.log("My language updated to: \(myLang) from Firestore in RoomViewModel.", level: .info)
                    }
                } else if room == nil {
                    self.errorMessage = "Room no longer exists."
                    Logger.log("Room \(self.roomID) no longer exists.", level: .warning)
                }
            }
            .store(in: &cancellables)

        // MARK: Fix 1: Change $transcribedText to $recognizedText
        speechManager.$recognizedText
            // MARK: Fix 2: Explicitly define the time unit for debounce
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main) // Using .seconds(0.3) for clarity
            .removeDuplicates()
            // MARK: Fix 3: Add type annotation for 'text'
            .sink { [weak self] (text: String) in
                guard let self = self else { return }
                // Use speechManager.liveRecognizedText if you want to send partial results
                // However, handleTranscribedText is likely for final results, so recognizedText is correct here.
                if self.speechManager.isRecording && !text.isEmpty {
                    self.handleTranscribedText(text)
                }
            }
            .store(in: &cancellables)
            
        speechManager.$isRecording
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                // This condition makes more sense if it passes the microphone AFTER
                // the current user has finished speaking and isRecording goes false.
                // If it's intended to pass immediately when they stop, this is fine.
                if !isRecording && self.canSpeak {
                    // Consider if you want to pass microphone only if there's actual spoken text
                    // or just when recording stops regardless of input.
                    self.passMicrophoneToOtherUser()
                }
            }
            .store(in: &cancellables)
            
        setupRealtimeListeners()
    }
    
    func setupRealtimeListeners() {
        messageListener?.remove()
            
        // 💡 الإصلاح هنا: نستخدم دالة `listenToMessages` الجديدة من FirestoreService
        messageListener = firestoreService.listenToMessages(roomID: roomID) { [weak self] fetchedMessages, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = "Error fetching messages: \(error.localizedDescription)"
                Logger.log(self.errorMessage!, level: .error)
                return
            }
            
            self.messages = fetchedMessages
            Logger.log("Messages updated. Total: \(self.messages.count)", level: .debug)
            
            // 💡 الإصلاح هنا: فك الـ Optional لـ `translatedText` باستخدام `?? ""`
            if let lastMessage = self.messages.last, lastMessage.senderUID != self.currentUser.id {
                self.speakTranslatedText(lastMessage.translatedText ?? "")
            }
        }
    }

    private func updateParticipants(room: Room) {
        let otherParticipantUID = room.participantUIDs.first(where: { $0 != currentUser.id })
            
        if let uid = otherParticipantUID {
            Task { @MainActor in
                do {
                    self.otherParticipant = try await firestoreService.fetchUser(uid: uid)
                    Logger.log("Other participant in room: \(self.otherParticipant?.displayName ?? "N/A")", level: .info)
                } catch {
                    Logger.log("Error fetching other participant: \(error.localizedDescription)", level: .error)
                    self.otherParticipant = nil
                }
            }
        } else {
            self.otherParticipant = nil
            Logger.log("No other participant in room yet.", level: .info)
        }
    }

    private func updateMicrophoneControl(room: Room) {
        if let roomActiveSpeakerUID = room.activeSpeakerUID, roomActiveSpeakerUID != activeSpeakerUID {
            self.activeSpeakerUID = roomActiveSpeakerUID
            Logger.log("Room's active speaker updated from Firestore: \(roomActiveSpeakerUID)", level: .info)
        } else if activeSpeakerUID == nil && room.hostUserID == currentUser.id {
            self.activeSpeakerUID = currentUser.id
            Logger.log("Initial active speaker set to host: \(currentUser.id ?? "Unknown")", level: .info)
        }
            
        self.canSpeak = (self.activeSpeakerUID == currentUser.id)
        Logger.log("Microphone control: Current active speaker is \(self.activeSpeakerUID ?? "None"). Can current user speak: \(self.canSpeak)", level: .info)
    }
    
    func toggleMicrophone() {
        guard canSpeak else {
            errorMessage = "It's not your turn to speak."
            Logger.log("Attempted to speak when not allowed.", level: .warning)
            return
        }

        if speechManager.isRecording {
            speechManager.stopRecording()
        } else {
            // MARK: Fix 4: Pass languageCode to startRecording()
            speechManager.startRecording(languageCode: userLanguageCode) // Pass the user's language code
        }
    }
    
    private func handleTranscribedText(_ text: String) {
        guard !text.isEmpty else { return }

        Logger.log("Transcribed text: \(text)", level: .debug)

        Task { @MainActor in
            do {
                let targetLanguageCode = otherParticipantLanguageCode()
                let translatedText = try await translationService.translate(text: text, sourceLanguage: userLanguageCode, targetLanguage: targetLanguageCode)
                
                Logger.log("Translated text: \(translatedText)", level: .debug)
                
                // ✨ Create Message struct
                let newMessage = Message(
                    senderUID: currentUser.id ?? "unknown",
                    originalText: text,
                    translatedText: translatedText,
                    originalLanguageCode: userLanguageCode,
                    targetLanguageCode: targetLanguageCode,
                    senderPreferredVoiceGender: currentUser.preferredVoiceGender ?? "default"
                )
                
                try await self.firestoreService.addMessageToRoom(roomID: roomID, message: newMessage)
                Logger.log("Message sent to Firestore successfully.", level: .info)
                
            } catch {
                errorMessage = "Translation or sending message failed: \(error.localizedDescription)"
                Logger.log("Error in handleTranscribedText: \(error.localizedDescription)", level: .error)
            }
        }
    }

    private func otherParticipantLanguageCode() -> String {
        // ✨ هنا يجب أن تحاول جلب لغة الطرف الآخر من otherParticipant
        // إذا لم يكن هناك otherParticipant أو كانت لغته غير محددة،
        // افترض لغة بديلة (مثلاً، إذا كانت لغتي الإنجليزية، فالأخرى العربية، والعكس)
        // يجب أن نستخدم لغة `userLanguageCode` الحالية للمستخدم
        return otherParticipant?.preferredLanguageCode ?? (userLanguageCode == "en-US" ? "ar-SA" : "en-US")
    }

    private func sendMessageToFirestore(message: Message) async throws {
        try await firestoreService.addMessageToRoom(roomID: roomID, message: message)
        Logger.log("Message sent to Firestore successfully.", level: .info)
    }
    
    private func passMicrophoneToOtherUser() {
        guard let currentRoom = firestoreService.currentFirestoreRoom else { return }
            
        let participants = currentRoom.participantUIDs
        if participants.count > 1 {
            if let activeSpeaker = activeSpeakerUID {
                let nextSpeaker = participants.first(where: { $0 != activeSpeaker })
                self.activeSpeakerUID = nextSpeaker
                Logger.log("Microphone passed to: \(nextSpeaker ?? "None")", level: .info)
                
                Task { @MainActor in
                    await updateRoomActiveSpeakerInFirestore(newActiveSpeakerUID: nextSpeaker)
                }
            }
        } else {
            Logger.log("Only one participant, cannot pass microphone.", level: .warning)
        }
    }
    
    @MainActor
    private func updateRoomActiveSpeakerInFirestore(newActiveSpeakerUID: String?) async {
        guard let currentRoomID = firestoreService.currentFirestoreRoom?.id else { return }
        do {
            try await firestoreService.updateRoomActiveSpeaker(roomID: currentRoomID, activeSpeakerUID: newActiveSpeakerUID)
            Logger.log("activeSpeakerUID updated in Firestore to: \(newActiveSpeakerUID ?? "nil")", level: .info)
        } catch {
            Logger.log("Error updating activeSpeakerUID in Firestore: \(error.localizedDescription)", level: .error)
        }
    }

    @MainActor
    func endConversation() async {
        guard let room = firestoreService.currentFirestoreRoom, let roomID = room.id else {
            Logger.log("No active room to end.", level: .warning)
            return
        }

        speechManager.stopRecording()
        messageListener?.remove()
        firestoreService.stopListeningToRoom()
            
        do {
            try await firestoreService.deleteRoomAndSubcollections(roomID: roomID)
            Logger.log("Room \(roomID) deleted successfully.", level: .info)
        } catch {
            errorMessage = "Failed to end conversation: \(error.localizedDescription)"
            Logger.log("Error deleting room \(roomID): \(error.localizedDescription)", level: .error)
        }
    }
    
    func speakTranslatedText(_ text: String) {
        // This is where you would call your TextToSpeechService to speak the text.
        // Assuming you have an instance of TextToSpeechService available, e.g., injected like SpeechManager.
        // For now, let's just log and remind ourselves.
        // You'll need to define a TextToSpeechService property and inject it similarly to SpeechManager.
        Logger.log("Attempting to speak: \(text)", level: .info)
            
        // Example if you have a TextToSpeechService injected:
        // self.textToSpeechService.speak(text: text, languageCode: userLanguageCode) // Or otherParticipantLanguageCode()
        // If TextToSpeechService is not injected in RoomViewModel, you might need to adjust or inject it.
    }

    deinit {
        cancellables.removeAll()
        messageListener?.remove()
        firestoreService.stopListeningToRoom()
        speechManager.stopRecording()
        Logger.log("RoomViewModel deinitialized for room ID: \(roomID).", level: .info)
    }
}
