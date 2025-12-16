import Foundation
import FirebaseFirestore
import Combine

class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    
    private var roomListener: ListenerRegistration?
    
    @Published var currentFirestoreRoom: Room?
    
    deinit {
        roomListener?.remove()
        Logger.log("FirestoreService deinitialized. Room listener removed.", level: .info)
    }

    // MARK: - User Operations
    func fetchUser(uid: String) async throws -> User? {
        do {
            // ✨ مهم: عند جلب المستخدم، تأكد أنك تقوم بجلب كل الخصائص بما في ذلك preferredLanguageCode
            // الدالة `getDocument(as: User.self)` يفترض أنها تقوم بذلك تلقائيًا إذا كان User struct متوافقاً
            let user = try await db.collection("users").document(uid).getDocument(as: User.self)
            Logger.log("Successfully fetched user \(uid). Preferred Language Code: \(user.preferredLanguageCode ?? "N/A")", level: .info)
            return user
        } catch let error as DecodingError {
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
        let uid = user.uid
        
        do {
            try db.collection("users").document(uid).setData(from: user, merge: true)
            Logger.log("User \(uid) data saved/updated in Firestore.", level: .info)
        } catch {
            Logger.log("Error saving user \(uid) to Firestore: \(error.localizedDescription)", level: .error)
            throw AppError.firestoreError("Failed to save user: \(error.localizedDescription)")
        }
    }

    // ✨ الدالة الجديدة هنا لتحديث لغة المستخدم المفضلة في مستند المستخدم
    func updateUserPreferredLanguage(userID: String, languageCode: String) async throws {
        let userRef = db.collection("users").document(userID)
        do {
            try await userRef.updateData(["preferredLanguageCode": languageCode])
            Logger.log("User \(userID) preferred language updated to \(languageCode) in their user document.", level: .info)
        } catch {
            Logger.log("Error updating user \(userID) preferred language: \(error.localizedDescription)", level: .error)
            throw error
        }
    }

    // MARK: - Room Operations

    func createRoom(room: Room) async throws -> Room {
        var roomToSave = room // Make it mutable
        // Assume `createdAt` is a property in your Room struct
        // roomToSave.createdAt = Timestamp(date: Date())

        // Use addDocument(from:) which takes an Encodable object directly
        let documentRef = try await db.collection("rooms").addDocument(from: roomToSave)
        
        let newRoomID = documentRef.documentID
        Logger.log("Room successfully created with Firestore-generated ID: \(newRoomID)", level: .info)
        
        // Update the ID of the room object you're returning
        roomToSave.id = newRoomID
        
        // IMPORTANT: Immediately start listening to this newly created room
        await listenToRoomRealtime(roomID: newRoomID)
        
        return roomToSave // Return the updated room with the Firestore ID
    }

    func joinRoom(roomID: String, participantUserID: String) async throws -> Room {
        let roomRef = self.db.collection("rooms").document(roomID)

        // The closure for runTransaction is non-throwing and returns Any?
        let result = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let roomDocument: DocumentSnapshot
            do {
                roomDocument = try transaction.getDocument(roomRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError // Set the error for the transaction to pick up
                return nil // Return nil on error
            }
            
            // Make sure `room` is mutable
            guard var room = try? roomDocument.data(as: Room.self) else {
                let error = NSError(domain: "AppError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Room not found or invalid data for room ID: \(roomID)"])
                errorPointer?.pointee = error
                return nil // Return nil on error
            }
            
            guard room.participantUIDs.count < 2 else {
                let error = NSError(domain: "AppError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Room is already full."])
                errorPointer?.pointee = error
                return nil
            }
            
            if !room.participantUIDs.contains(participantUserID) {
                room.participantUIDs.append(participantUserID)
            }
            
            if room.participantUIDs.count == 2 {
                room.status = .active
                Logger.log("Room \(roomID) status set to active.", level: .info)
            }
            
            // Update the document in the transaction using setData(from: ...)
            // Remove 'try' keyword since we're handling errors through errorPointer
            do {
                try transaction.setData(from: room, forDocument: roomRef)
            } catch let setDataError as NSError {
                errorPointer?.pointee = setDataError
                return nil
            }
            
            Logger.log("User \(participantUserID) successfully joined room \(roomID).", level: .info)
            
            // For the joining client, start listening to this room immediately
            Task { @MainActor in
                await self.listenToRoomRealtime(roomID: roomID)
            }
            
            return room // Return the updated room object from the transaction
        } as? Room
        
        guard let room = result else {
            throw AppError.firestoreError("Failed to join room - transaction returned invalid result")
        }
        
        return room
    }
    
    @MainActor
        func leaveRoom(roomID: String, participantUserID: String) async throws {
            let roomRef = db.collection("rooms").document(roomID)
            
            try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let roomDocument: DocumentSnapshot
                do {
                    roomDocument = try transaction.getDocument(roomRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                guard var room = try? roomDocument.data(as: Room.self) else {
                    let error = NSError(domain: "AppError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Room not found or invalid data."])
                    errorPointer?.pointee = error
                    return nil
                }
                
                Logger.log("👤 Removing participant \(participantUserID) from room \(roomID)", level: .info)
                
                // ✅ الخطوة 1: إزالة المستخدم من قائمة المشاركين
                room.participantUIDs.removeAll(where: { $0 == participantUserID })
                room.participantLanguages?[participantUserID] = nil
                
                // ✅ الخطوة 2: تحديث المنطق: حذف الغرفة إذا كان عدد المشاركين 0
                if room.participantUIDs.isEmpty {
                    // إذا لم يبقَ أحد - احذف الغرفة
                    Logger.log("🗑️ No participants left. Deleting room \(roomID).", level: .info)
                    transaction.deleteDocument(roomRef)
                } else if room.participantUIDs.count == 1 {
                    // إذا بقي مشارك واحد فقط - اجعل الغرفة محتفلة لكي يخرج المستخدم الآخر
                    Logger.log("⚠️ One participant left. Marking room \(roomID) as 'ending'.", level: .info)
                    room.status = .ended
                    do {
                        try transaction.setData(from: room, forDocument: roomRef)
                        Logger.log("✅ Room \(roomID) marked as 'ended'. Waiting for last participant to leave.", level: .info)
                    } catch let setDataError as NSError {
                        errorPointer?.pointee = setDataError
                        return nil
                    }
                } else {
                    // إذا كان هناك أكثر من مشارك واحد
                    Logger.log("✅ User removed. Still have \(room.participantUIDs.count) participants. Updating room.", level: .info)
                    do {
                        try transaction.setData(from: room, forDocument: roomRef)
                    } catch let setDataError as NSError {
                        errorPointer?.pointee = setDataError
                        return nil
                    }
                }
                return nil
            }
            
            // ✅ الخطوة 3: بعد نجاح الـ Transaction، تحقق من حذف الغرفة
            let roomDoc = try await roomRef.getDocument()
            
            if !roomDoc.exists {
                Logger.log("🗑️ Room \(roomID) was deleted. Now deleting its messages.", level: .info)
                try await deleteRoomMessages(roomID: roomID)
            }
        }

    // MARK: - Real-time Listener Management
    @MainActor
    func listenToRoomRealtime(roomID: String) async {
        stopListeningToRoom() // Stop any existing listener
        
        let roomRef = db.collection("rooms").document(roomID)
        
        roomListener = roomRef.addSnapshotListener { [weak self] documentSnapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Error listening to room \(roomID): \(error.localizedDescription)", level: .error)
                DispatchQueue.main.async {
                    self.currentFirestoreRoom = nil
                }
                return
            }
            
            guard let document = documentSnapshot else {
                Logger.log("Room document \(roomID) snapshot is nil.", level: .warning)
                DispatchQueue.main.async {
                    self.currentFirestoreRoom = nil
                }
                return
            }
            
            guard document.exists else {
                Logger.log("Room document \(roomID) no longer exists (likely deleted).", level: .info)
                DispatchQueue.main.async {
                    self.currentFirestoreRoom = nil
                    // Ensure the listener is stopped if the document is deleted
                    self.stopListeningToRoom()
                }
                return
            }
            
            do {
                let room = try document.data(as: Room.self)
                DispatchQueue.main.async {
                    self.currentFirestoreRoom = room
                    Logger.log("Realtime update for room \(room.id ?? "N/A"). Status: \(room.status). Participants: \(room.participantUIDs.count)", level: .debug)
                }
            } catch {
                Logger.log("Error decoding room data from snapshot for room \(roomID): \(error.localizedDescription)", level: .error)
                DispatchQueue.main.async {
                    self.currentFirestoreRoom = nil
                }
            }
        }
        Logger.log("Started internal real-time listener for room \(roomID).", level: .info)
    }

    func stopListeningToRoom() {
        roomListener?.remove()
        roomListener = nil
        DispatchQueue.main.async {
            self.currentFirestoreRoom = nil
        }
        Logger.log("Stopped any active room listener and cleared currentFirestoreRoom.", level: .info)
    }
    
    // This function for ConversationViewModel
    func listenToRoom(roomID: String, completion: @escaping (Result<Room, Error>) -> Void) -> ListenerRegistration {
        let roomRef = db.collection("rooms").document(roomID)
        
        let listener = roomRef.addSnapshotListener { documentSnapshot, error in
            if let error = error {
                Logger.log("Error listening to room document: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
                return
            }
            
            guard let document = documentSnapshot, document.exists else {
                Logger.log("Room document \(roomID) does not exist or was deleted.", level: .warning)
                completion(.failure(AppError.firestoreError("Room not found or deleted.")))
                return
            }
            
            do {
                let room = try document.data(as: Room.self)
                DispatchQueue.main.async {
                    completion(.success(room))
                }
            } catch {
                Logger.log("Error decoding room data from snapshot \(roomID): \(error.localizedDescription)", level: .error)
                completion(.failure(error))
            }
        }
        
        Logger.log("Started listening to room \(roomID) realtime updates via 'listenToRoom' (for ConversationViewModel).", level: .info)
        return listener
    }
    
    // MARK: - Message Operations
            
    func addMessageToRoom(roomID: String, message: Message) async throws {
        let roomMessagesCollection = db.collection("rooms").document(roomID).collection("messages")
        
        do {
            try await roomMessagesCollection.addDocument(from: message)
            Logger.log("Message added to room \(roomID).", level: .info)
        } catch {
            Logger.log("Error adding message to room \(roomID): \(error.localizedDescription)", level: .error)
            throw error
        }
    }
            
    func listenToMessages(roomID: String, completion: @escaping ([Message], Error?) -> Void) -> ListenerRegistration {
        return db.collection("rooms").document(roomID).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    Logger.log("Error listening to messages: \(error.localizedDescription)", level: .error)
                    completion([], error)
                    return
                }
                
                // ✨ تحديث: قراءة الحقول الجديدة من XTTS v2 Backend
                let fetchedMessages = querySnapshot?.documents.compactMap { document -> Message? in
                    do {
                        let message = try document.data(as: Message.self)
                        return message
                    } catch {
                        Logger.log("Error decoding message: \(error)", level: .error)
                        return nil
                    }
                } ?? []
                
                Logger.log("✅ Fetched \(fetchedMessages.count) messages with XTTS data", level: .info)
                completion(fetchedMessages, nil)
            }
    }
    
    func updateRoomActiveSpeaker(roomID: String, activeSpeakerUID: String?) async throws {
        let roomRef = db.collection("rooms").document(roomID)
        try await roomRef.updateData(["activeSpeakerUID": activeSpeakerUID as Any])
    }

    // الكود الجديد والمُعدَّل
    // ✅ دالة جديدة: حذف رسائل الغرفة فقط (بدون حذف الغرفة نفسها)
    func deleteRoomMessages(roomID: String) async throws {
        Logger.log("🗑️ Starting to delete messages for room \(roomID)...", level: .info)
        
        let messagesCollection = db.collection("rooms").document(roomID).collection("messages")
        let messages = try await messagesCollection.getDocuments().documents
        
        Logger.log("📊 Found \(messages.count) messages to delete.", level: .info)
        
        if messages.isEmpty {
            Logger.log("✅ No messages to delete for room \(roomID).", level: .info)
            return
        }
        
        // استخدم 'batch' للحذف الجماعي ليكون أسرع وأكثر كفاءة
        let batch = db.batch()
        for message in messages {
            batch.deleteDocument(messagesCollection.document(message.documentID))
        }
        
        try await batch.commit()
        Logger.log("✅ All \(messages.count) messages for room \(roomID) have been deleted.", level: .info)
        
        // حذف وثيقة الغرفة نفسها بعد حذف الرسائل
        try await db.collection("rooms").document(roomID).delete()
        Logger.log("✅ Room \(roomID) document has been deleted.", level: .info)
    }
    
    func deleteRoomAndSubcollections(roomID: String) async throws {
        // الخطوة 1: حذف جميع الرسائل في المجموعة الفرعية 'messages'
        let messagesCollection = db.collection("rooms").document(roomID).collection("messages")
        let messages = try await messagesCollection.getDocuments().documents
        
        // استخدم 'batch' للحذف الجماعي ليكون أسرع وأكثر كفاءة
        let batch = db.batch()
        for message in messages {
            batch.deleteDocument(messagesCollection.document(message.documentID))
        }
        
        try await batch.commit()
        Logger.log("All messages for room \(roomID) have been deleted.", level: .info)
        
        // الخطوة 2: حذف وثيقة الغرفة نفسها
        try await db.collection("rooms").document(roomID).delete()
        Logger.log("Room \(roomID) has been deleted.", level: .info)
    }
            
    func updateRoomParticipantLanguage(roomID: String, userID: String, languageCode: String) async {
        let roomRef = db.collection("rooms").document(roomID)
        let data = ["participantLanguages.\(userID)": languageCode]
                    
        do {
            try await roomRef.updateData(data)
            Logger.log("User \(userID) language updated to \(languageCode) in room \(roomID).", level: .info)
        } catch {
            Logger.log("Error updating participant language in room \(roomID) for user \(userID): \(error.localizedDescription)", level: .error)
        }
    }
    
    // MARK: - Message Translation Re-fetch
    func fetchMessageTranslations(messageID: String, roomID: String, completion: @escaping (Message?) -> Void) {
        let messageRef = db.collection("rooms").document(roomID).collection("messages").document(messageID)
        
        messageRef.getDocument { document, error in
            if let error = error {
                Logger.log("Error fetching message translations for \(messageID): \(error.localizedDescription)", level: .error)
                completion(nil)
                return
            }
            
            guard let document = document, document.exists else {
                Logger.log("Message document \(messageID) not found.", level: .warning)
                completion(nil)
                return
            }
            
            do {
                let message = try document.data(as: Message.self)
                Logger.log("Successfully fetched message \(messageID) with translations: \(message.translations?.description ?? "none")", level: .info)
                completion(message)
            } catch {
                Logger.log("Error decoding message \(messageID): \(error.localizedDescription)", level: .error)
                completion(nil)
            }
        }
    }
}
