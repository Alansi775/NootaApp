// Noota/ViewModels/ConversationViewModel.swift
import Foundation
import Combine
import SwiftUI
import FirebaseFirestore // أضف هذا الاستيراد للتعرف على Timestamp (إذا كنت تستخدمه في نماذج أخرى)

class ConversationViewModel: ObservableObject {
    @Published var currentRoom: Room
    @Published var currentUser: User
    @Published var opponentUser: User
    
    @Published var selectedLanguage: String // لغة المستخدم الحالي
    @Published var opponentLanguage: String? // لغة المستخدم الآخر

    @Published var isRecording: Bool = false
    @Published var recordedText: String = ""
    @Published var translatedText: String = ""
    
    @Published var messages: [ChatMessage] = []
    
    private let firestoreService: FirestoreService
    private var cancellables = Set<AnyCancellable>()

    let supportedLanguages = [
        "English": "en-US",
        "العربية": "ar-SA",
        "Türkçe": "tr-TR"
    ]
    
    init(room: Room, currentUser: User, opponentUser: User, firestoreService: FirestoreService) {
        self.currentRoom = room
        self.currentUser = currentUser
        self.opponentUser = opponentUser
        self.firestoreService = firestoreService
        
        // ✨ القيمة الافتراضية: حاول قراءة لغة المستخدم من الغرفة، وإلا فاستخدم "en-US"
        self.selectedLanguage = room.participantLanguages?[currentUser.uid] ?? "en-US"
        
        // ✨ قم بتهيئة لغة الخصم أيضًا عند التهيئة
        self.opponentLanguage = room.participantLanguages?[opponentUser.uid]
        
        setupFirestoreListener()
        setupMessagesListener() // تأكد من وجود دالة للاستماع إلى الرسائل
    }

    private func setupFirestoreListener() {
        firestoreService.$currentFirestoreRoom
            .compactMap { $0 }
            .filter { [weak self] room in room.id == self?.currentRoom.id }
            .sink { [weak self] updatedRoom in
                guard let self = self else { return }
                
                // تحديث الغرفة
                self.currentRoom = updatedRoom
                
                // ✨ تحديث لغة المستخدم الحالي من الغرفة المحدثة
                if let myLang = updatedRoom.participantLanguages?[self.currentUser.uid],
                   self.selectedLanguage != myLang {
                    self.selectedLanguage = myLang
                    Logger.log("My language updated to: \(myLang) from Firestore.", level: .info)
                }
                
                // تحديث لغة الخصم
                if let languages = updatedRoom.participantLanguages,
                   let oppLang = languages[self.opponentUser.uid],
                   self.opponentLanguage != oppLang {
                    self.opponentLanguage = oppLang
                    Logger.log("Opponent language updated to: \(oppLang)", level: .info)
                }
            }
            .store(in: &cancellables)
    }
    
    // ✨ دالة للاستماع إلى الرسائل (مهمة لعرض الرسائل في الواجهة)
    private func setupMessagesListener() {
            guard let roomID = currentRoom.id else {
                Logger.log("Cannot setup messages listener: Room ID is nil.", level: .error)
                return
            }
            
            // ✨ هذا هو التغيير الرئيسي: استخدام .sink للاشتراك في الـ Publisher
            firestoreService.listenToRoomMessages(roomID: roomID)
                .sink { completion in
                    // هنا يمكنك التعامل مع حالات اكتمال الـ Publisher (مثل .finished أو .failure)
                    switch completion {
                    case .finished:
                        Logger.log("Message listener finished for room: \(roomID)", level: .info)
                    case .failure(let error):
                        Logger.log("Error in message listener for room \(roomID): \(error.localizedDescription)", level: .error)
                        // يمكنك عرض تنبيه للمستخدم هنا إذا كان الخطأ حرجًا
                    }
                } receiveValue: { [weak self] fetchedMessages in
                    // هنا تتلقى القيم الجديدة (مصفوفة الرسائل)
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        // فرز الرسائل حسب الطابع الزمني لضمان الترتيب الصحيح
                        self.messages = fetchedMessages.sorted(by: { $0.timestamp < $1.timestamp })
                        Logger.log("Fetched \(self.messages.count) messages for room \(roomID).", level: .info)
                    }
                }
                .store(in: &cancellables) // مهم جدًا: تخزين الـ cancellable لمنع إيقاف الـ listener مبكرًا
        }
    
    @MainActor
    func updateMyLanguageInRoom(languageCode: String) async {
        guard let roomID = currentRoom.id else {
            Logger.log("Failed to get roomID for language update.", level: .error)
            return
        }
        
        // ✨ قم بتحديث القيمة المحلية مباشرة لتنعكس في الواجهة فورًا
        self.selectedLanguage = languageCode
        
        await firestoreService.updateRoomParticipantLanguage(roomID: roomID, userID: currentUser.uid, languageCode: languageCode)
        Logger.log("Attempted to update my language in Firestore to: \(languageCode)", level: .info)
    }

    func startRecording() {
        isRecording = true
        recordedText = "" // مسح النص المسجل القديم
        translatedText = "" // مسح النص المترجم القديم
        Logger.log("Start recording...", level: .info)
        // ✨ هنا يجب أن تبدأ عملية التعرف على الكلام
    }

    func stopRecording() {
        isRecording = false
        Logger.log("Stop recording.", level: .info)
        // ✨ هنا يجب أن تتوقف عملية التعرف على الكلام ومعالجة النص المسجل
        // على سبيل المثال، استدعاء translateAndSendMessage
        // translateAndSendMessage(text: recordedText, fromLanguage: selectedLanguage, toLanguage: opponentLanguage ?? "en-US")
    }
    
    @MainActor
    func translateAndSendMessage(text: String, fromLanguage: String, toLanguage: String) async {
        Logger.log("Translating '\(text)' from \(fromLanguage) to \(toLanguage).", level: .info)
        
        // افتراضيًا، النص المترجم هو نفسه النص الأصلي إذا لم يكن هناك ترجمة فعلية بعد
        var finalTranslatedText: String? = nil
        // ✨ هنا يجب عليك استدعاء خدمة الترجمة الفعلية
        // على سبيل المثال:
        // if let translated = await TranslationService.shared.translate(text: text, from: fromLanguage, to: toLanguage) {
        //     finalTranslatedText = translated
        // } else {
        //     finalTranslatedText = "Translation failed for: \(text)" // رسالة خطأ
        // }
        
        // لغرض الاختبار حتى يتم تطبيق خدمة الترجمة الفعلية:
        finalTranslatedText = "Translated: \(text)"
        
        let newMessage = ChatMessage(id: UUID().uuidString, senderUID: currentUser.uid, text: text, translatedText: finalTranslatedText, timestamp: Date())
        
        // إضافة الرسالة إلى Firestore
        if let roomID = currentRoom.id {
            await firestoreService.addMessageToRoom(roomID: roomID, message: newMessage)
            Logger.log("Message added to Firestore: \(newMessage.id)", level: .info)
        } else {
            Logger.log("Failed to add message: Room ID is nil.", level: .error)
        }
    }

    @MainActor
    func leaveRoom() async {
        Logger.log("Leaving room: \(currentRoom.id ?? "N/A")", level: .info)
        if let roomID = currentRoom.id {
            await firestoreService.leaveRoom(roomID: roomID, participantUserID: currentUser.uid)
        } else {
            Logger.log("Failed to leave room: Room ID is nil.", level: .error)
        }
    }
}

// تعريف هيكل الرسالة (ChatMessage)
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let senderUID: String
    let text: String // النص الأصلي
    var translatedText: String? // النص المترجم (اختياري)
    let timestamp: Date // استخدام Date بدلاً من Timestamp لتوافق Codable
    
    // يمكن لـ FirebaseFirestore SDK التعامل مع تحويل Date إلى Timestamp تلقائيًا عند حفظها
    // والعكس صحيح عند قراءة Timestamp كـ Date.
}
