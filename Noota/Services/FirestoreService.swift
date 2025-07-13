// Noota/Services/FirestoreService.swift
import Foundation
import FirebaseFirestore // مهم لاستخدام @DocumentID و Convenience Initializers
import Combine

class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    private var roomListener: ListenerRegistration? // لتخزين listener الخاص بالغرفة
    
    // ✨ جديد: خاصية منشورة لتتبع الغرفة الحالية في Service
    // هذه الخاصية سيتم تحديثها باستمرار من خلال الـ listener
    @Published var currentFirestoreRoom: Room?
    
    
    deinit {
        // إزالة listener عند إلغاء تهيئة الكائن لتجنب تسرب الذاكرة
        roomListener?.remove()
        Logger.log("FirestoreService deinitialized. Room listener removed.", level: .info)
    }

    // MARK: - User Operations (احتفظ بها كما هي أو عدّلها لتناسب احتياجاتك)
    // 💡 تم تحويل fetchUser إلى async/await لدعم الكود الجديد في MainAppView
    func fetchUser(uid: String) async throws -> User? {
        do {
            let user = try await db.collection("users").document(uid).getDocument(as: User.self)
            Logger.log("Successfully fetched user \(uid).", level: .info)
            return user
        } catch let error as DecodingError {
            // التعامل مع حالة عدم وجود المستند بشكل خاص
            if case .dataCorrupted(let context) = error, context.debugDescription.contains("document not found") {
                Logger.log("User document \(uid) not found.", level: .warning)
                return nil
            } else {
                Logger.log("Error decoding user \(uid) from Firestore: \(error.localizedDescription)", level: .error)
                throw error
            }
        } catch {
            Logger.log("Error fetching user \(uid) from Firestore: \(error.localizedDescription)", level: .error)
            throw error
        }
    }
    
    func saveUser(user: User) async throws {
        // تم إصلاح الخطأ الأول: user.uid ليس اختيارياً بعد الآن
        let uid = user.uid
        
        do {
            try db.collection("users").document(uid).setData(from: user, merge: true)
            Logger.log("User \(uid) data saved/updated in Firestore.", level: .info)
        } catch {
            Logger.log("Error saving user \(uid) to Firestore: \(error.localizedDescription)", level: .error)
            throw AppError.firestoreError("Failed to save user: \(error.localizedDescription)")
        }
    }

    // MARK: - Room Operations

    // دالة لإنشاء غرفة جديدة في Firestore
    func createRoom(room: Room) async throws -> Room {
        var roomToSave = room
        if roomToSave.id == nil {
            roomToSave.id = UUID().uuidString
        }
        
        
        do {
            try await db.collection("rooms").document(roomToSave.id!).setData(from: roomToSave)
            Logger.log("Room successfully created with ID: \(roomToSave.id ?? "N/A")", level: .info)
            // 💡 بدء الاستماع للغرفة فور إنشائها
            self.listenToRoomRealtime(roomID: roomToSave.id!)
            return roomToSave
        } catch {
            Logger.log("Error writing room to Firestore: \(error.localizedDescription)", level: .error)
            throw AppError.firestoreError("Failed to create room: \(error.localizedDescription)")
        }
    }

    // دالة للانضمام إلى غرفة موجودة (تحديث participantUIDs)
    func joinRoom(roomID: String, participantUserID: String) async throws -> Room {
        let roomRef = self.db.collection("rooms").document(roomID)

        do {
            // جلب الغرفة للتأكد من وجودها وللحصول على القائمة الحالية للمشاركين
            var room = try await roomRef.getDocument(as: Room.self) // استخدام async/await هنا
            
            // تحقق من أن الغرفة ليست ممتلئة (إذا كان لديك حد للمشاركين)
            if room.participantUIDs.count >= 2 { // مثال: إذا كان الحد الأقصى 2
                throw AppError.firestoreError("Room is already full.")
            }

            if !room.participantUIDs.contains(participantUserID) {
                room.participantUIDs.append(participantUserID)
            }
            room.status = .active // تحديث الحالة إلى "active" عند الانضمام

            // حفظ التغييرات على الغرفة
            try await roomRef.setData(from: room, merge: true)
            Logger.log("Room \(roomID) successfully joined/updated by \(participantUserID)", level: .info)
            // 💡 بدء الاستماع للغرفة فور الانضمام إليها
            self.listenToRoomRealtime(roomID: roomID)
            return room

        } catch let error as DecodingError {
            if case .dataCorrupted(let context) = error, context.debugDescription.contains("document not found") {
                Logger.log("Room '\(roomID)' not found during join attempt.", level: .warning)
                throw AppError.firestoreError("Room '\(roomID)' not found.")
            } else {
                Logger.log("Error decoding room during join attempt: \(error.localizedDescription)", level: .error)
                throw error
            }
        } catch {
            Logger.log("Failed to join room \(roomID): \(error.localizedDescription)", level: .error)
            throw error
        }
    }
    
    // دالة للاستماع إلى التغييرات في غرفة معينة بشكل مباشر (Realtime)
    func listenToRoomRealtime(roomID: String) {
        // إزالة أي listener سابق قبل إنشاء listener جديد
        roomListener?.remove()

        roomListener = db.collection("rooms").document(roomID)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("Error fetching document snapshot for room listener \(roomID): \(error.localizedDescription)", level: .error)
                    // في حالة حدوث خطأ، قد ترغب في إعادة تعيين الغرفة الحالية
                    DispatchQueue.main.async { // تأكد من التحديث على الـ Main Thread
                        self.currentFirestoreRoom = nil
                    }
                    return
                }

                guard let document = documentSnapshot else {
                    Logger.log("Document snapshot is nil for room \(roomID).", level: .warning)
                    DispatchQueue.main.async { // تأكد من التحديث على الـ Main Thread
                        self.currentFirestoreRoom = nil // ربما تم حذف الغرفة
                    }
                    return
                }
                
                // إذا تم حذف المستند من Firestore (document.exists == false)، فقم بتعيين الغرفة إلى nil
                if !document.exists {
                    Logger.log("Room document \(roomID) no longer exists. Setting currentFirestoreRoom to nil.", level: .info)
                    DispatchQueue.main.async {
                        self.currentFirestoreRoom = nil
                    }
                    return
                }

                do {
                    // استخدم `data(as: Room.self)` لجلب البيانات وفك تشفيرها
                    let room = try document.data(as: Room.self)
                    DispatchQueue.main.async { // تأكد من التحديث على الـ Main Thread
                        self.currentFirestoreRoom = room // تحديث الخاصية المنشورة
                    }
                    Logger.log("Room updated via realtime listener: \(room.id ?? "N/A") - Status: \(room.status) - Participants: \(room.participantUIDs.count)", level: .info)
                } catch {
                    Logger.log("Error decoding room from snapshot listener \(roomID): \(error.localizedDescription)", level: .error)
                    DispatchQueue.main.async { // تأكد من التحديث على الـ Main Thread
                        self.currentFirestoreRoom = nil // في حالة حدوث خطأ في فك التشفير
                    }
                }
            }
        Logger.log("Started listening to room \(roomID) realtime updates.", level: .info)
    }
    
    // دالة لإيقاف الاستماع للغرفة (مهمة عند الخروج من الغرفة)
    func stopListeningToRoom() {
        roomListener?.remove()
        roomListener = nil
        self.currentFirestoreRoom = nil // مسح الغرفة الحالية
        Logger.log("Stopped listening to room.", level: .info)
    }
    
    // دالة لمغادرة الغرفة (إزالة المستخدم من قائمة المشاركين)
    // ✨ تعديل دالة مغادرة الغرفة لتتناسب مع اسم البارامتر
     func leaveRoom(roomID: String, participantUserID: String) async {
         let roomRef = db.collection("rooms").document(roomID)
         
         do {
             // قم بإزالة الـ participantUserID من قائمة participantUIDs
             try await roomRef.updateData([
                 "participantUIDs": FieldValue.arrayRemove([participantUserID])
             ])
             
             Logger.log("User \(participantUserID) left room \(roomID).", level: .info)
             
             // تحقق إذا لم يتبق أحد في الغرفة، قم بتغيير الحالة إلى ended
             let roomDoc = try await roomRef.getDocument()
             if let roomData = roomDoc.data(),
                let currentParticipants = roomData["participantUIDs"] as? [String],
                currentParticipants.isEmpty {
                 try await roomRef.updateData(["status": Room.Status.ended.rawValue])
                 Logger.log("Room \(roomID) status changed to ended as all participants left.", level: .info)
             }
             
         } catch {
             Logger.log("Error leaving room \(roomID) for user \(participantUserID): \(error.localizedDescription)", level: .error)
         }
     }

    
    func listenToMessages(roomID: String, completion: @escaping ([Message], Error?) -> Void) -> ListenerRegistration {
        return db.collection("rooms").document(roomID).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    completion([], error)
                    return
                }
                let fetchedMessages = querySnapshot?.documents.compactMap { document -> Message? in
                    try? document.data(as: Message.self)
                } ?? []
                completion(fetchedMessages, nil)
            }
    }
    

    // MARK: - Message Operations (هذا الجزء لا يزال معلقاً، ستحتاجه عند بناء RoomView)
    func sendMessage(toRoomID roomID: String, message: Message) async throws {
        do {
            _ = try db.collection("rooms").document(roomID).collection("messages").addDocument(from: message)
            Logger.log("Message sent to room \(roomID).", level: .info)
        } catch {
            Logger.log("Error sending message to room \(roomID): \(error.localizedDescription)", level: .error)
            throw AppError.firestoreError("Failed to send message: \(error.localizedDescription)")
        }
    }
    
    func listenToRoomMessages(roomID: String) -> AnyPublisher<[ChatMessage], Error> { // ✨ تم تغيير [Message] إلى [ChatMessage]
        let subject = PassthroughSubject<[ChatMessage], Error>() // ✨ تم تغيير [Message] إلى [ChatMessage]

        let listener = self.db.collection("rooms").document(roomID).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    Logger.log("Error listening to messages in room \(roomID): \(error.localizedDescription)", level: .error)
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    subject.send([])
                    return
                }

                // ✨ هنا يجب أن تقوم بفك تشفير المستندات إلى ChatMessage.self
                let messages = documents.compactMap { document -> ChatMessage? in // ✨ تم تغيير Message.self إلى ChatMessage.self
                    try? document.data(as: ChatMessage.self) // تأكد أن ChatMessage conforms to Codable
                }
                subject.send(messages)
            }

        return subject.handleEvents(receiveCancel: {
            listener.remove()
            Logger.log("Stopped listening to messages in room \(roomID).", level: .info)
        })
        .eraseToAnyPublisher()
    }
    
    func updateRoomActiveSpeaker(roomID: String, activeSpeakerUID: String?) async throws {
            let roomRef = db.collection("rooms").document(roomID)
            try await roomRef.updateData(["activeSpeakerUID": activeSpeakerUID as Any])
        }

        // إضافة هذه الدالة (إذا لم تكن موجودة)
        func deleteRoom(roomID: String) async throws {
            try await db.collection("rooms").document(roomID).delete()
        }
    
    // ✨ دالة لإضافة رسالة إلى مجموعة فرعية (sub-collection) للرسائل
     func addMessageToRoom(roomID: String, message: ChatMessage) async {
         let roomMessagesCollection = db.collection("rooms").document(roomID).collection("messages")
         
         do {
             // Firebase Firestore لا يدعم الترميز المباشر لـ Timestamp في Struct
             // لذا سنستخدم Date ونحولها يدويا عند الحاجة
             // أو يمكننا تعريف Timestamp داخل ChatMessage كـ Date
             let messageData: [String: Any] = [
                 "id": message.id,
                 "senderUID": message.senderUID,
                 "text": message.text,
                 "translatedText": message.translatedText as Any, // استخدم as Any للتعامل مع الاختياري
                 "timestamp": Timestamp(date: message.timestamp) // تحويل Date إلى Timestamp
             ]
             
             try await roomMessagesCollection.addDocument(data: messageData)
             Logger.log("Message added to room \(roomID).", level: .info)
         } catch {
             Logger.log("Error adding message to room \(roomID): \(error.localizedDescription)", level: .error)
         }
     }
    
    // ✨ دالة جديدة لتحديث لغة مشارك في الغرفة
    func updateRoomParticipantLanguage(roomID: String, userID: String, languageCode: String) async {
        let roomRef = db.collection("rooms").document(roomID)
        let data = ["participantLanguages.\(userID)": languageCode] // تحديث حقل مدمج
        
        do {
            try await roomRef.updateData(data)
            Logger.log("User \(userID) language updated to \(languageCode) in room \(roomID).", level: .info)
        } catch {
            Logger.log("Error updating participant language in room \(roomID) for user \(userID): \(error.localizedDescription)", level: .error)
        }
    }
}
