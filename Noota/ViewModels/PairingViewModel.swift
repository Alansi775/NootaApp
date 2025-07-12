// Noota/ViewModels/PairingViewModel.swift هذا

import Foundation
import Combine
import FirebaseFirestore // تأكد من استيراد Firestore
import UIKit // لـ UIImage
import CoreImage // لإنشاء QR Code
import CoreImage.CIFilterBuiltins // لـ CIFilter.qrCodeGenerator

class PairingViewModel: ObservableObject {
    // ... (احتفظ بالخصائص الموجودة لديك)
    @Published var currentRoom: Room?// الغرفة الحالية التي تم إنشاؤها أو الانضمام إليها
    @Published var roomID: String = "" // لتخزين Room ID
    @Published var qrCodeImage: UIImage? // ✨ هذا هو المتغير الجديد أو الذي يجب أن يكون موجودًا
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var isDataFullyLoadedForConversation: Bool = false
    
    
    // ✨ جديد: خاصية للتحكم في الانتقال إلى شاشة المحادثة
    @Published var showConversationView: Bool = false
    
    // ✨ جديد: لتخزين بيانات المستخدم المقابل
    @Published var opponentUser: User?
    
    // Services
    private let firestoreService: FirestoreService
    let authService: AuthService // تأكد أنها غير private
    
    private var cancellables = Set<AnyCancellable>()

    init(firestoreService: FirestoreService, authService: AuthService) {
        self.firestoreService = firestoreService
        self.authService = authService
        
        // ✨ أضف هذا الـ subscriber للاستماع للتغييرات في الغرفة من FirestoreService
        firestoreService.$currentFirestoreRoom
            .receive(on: DispatchQueue.main) // تأكد من تلقي التحديثات على الـ Main Thread
            .sink { [weak self] room in
                guard let self = self else { return }
                
                // دائماً قم بتحديث هذه الخصائص أولاً
                self.currentRoom = room
                self.roomID = room?.id ?? ""
                
                if let id = room?.id {
                    self.generateQRCode(from: id)
                } else {
                    self.qrCodeImage = nil
                }
                
                Task { @MainActor in
                    if let activeRoom = room, activeRoom.status == .active && activeRoom.participantUIDs.count == 2 {
                        let currentUserID = self.authService.user?.id
                        let opponentID = activeRoom.participantUIDs.first(where: { $0 != currentUserID })
                        
                        if let opponentID = opponentID {
                            do {
                                let opponent = try await self.firestoreService.fetchUser(uid: opponentID)
                                self.opponentUser = opponent
                                
                                // ✨ الأهم: الآن فقط تأكد أن كل شيء جاهز للانتقال
                                // يجب أن تنتقل فقط عندما تكون جميع البيانات الضرورية موجودة
                                // تأكد أن self.currentRoom و self.opponentUser و self.authService.user كلها موجودة
                                if self.currentRoom != nil && self.authService.user != nil && self.opponentUser != nil {
                                    self.isDataFullyLoadedForConversation = true
                                    self.showConversationView = true // الآن فقط قم بتعيين showConversationView
                                    Logger.log("Room \(activeRoom.id ?? "N/A") is active, opponent fetched, and all data loaded. showConversationView set to true.", level: .info)
                                } else {
                                    // حالة غير متوقعة: البيانات ليست كاملة بعد الجلب
                                    Logger.log("Conversation data not fully ready after fetching opponent.", level: .error)
                                    self.isDataFullyLoadedForConversation = false
                                    self.showConversationView = false
                                }
                                
                            } catch {
                                self.errorMessage = "Failed to fetch opponent user: \(error.localizedDescription)"
                                Logger.log("Error fetching opponent user in sink: \(error.localizedDescription)", level: .error)
                                self.opponentUser = nil
                                self.isDataFullyLoadedForConversation = false
                                self.showConversationView = false
                            }
                        } else {
                            Logger.log("Room \(activeRoom.id ?? "N/A") is active, but opponent ID not found yet (currentUserID: \(currentUserID ?? "nil")).", level: .warning)
                            self.opponentUser = nil
                            self.isDataFullyLoadedForConversation = false
                            self.showConversationView = false
                        }
                    } else {
                        // الغرفة لم تعد موجودة أو لا تزال في حالة pending
                        self.opponentUser = nil
                        self.isDataFullyLoadedForConversation = false
                        self.showConversationView = false // تأكد أننا لسنا في شاشة المحادثة
                        if room == nil {
                            Logger.log("currentFirestoreRoom became nil. showConversationView set to false.", level: .info)
                        } else {
                            Logger.log("Room \(room?.id ?? "N/A") status: \(room?.status.rawValue ?? "N/A"). Waiting for opponent or active status.", level: .info)
                        }
                    }
                    self.isLoading = false
                }
            }
            .store(in: &self.cancellables)
    }

    @MainActor // تأكد من أن هذه الدوال تعمل على الـ Main Actor
    func createNewRoom() async {
        guard let currentUser = authService.user else {
            errorMessage = "User not logged in."
            Logger.log("Error creating room: User not logged in.", level: .error)
            return
        }
        
        isLoading = true
        errorMessage = nil

        let newRoom = Room(hostUserID: currentUser.id!, participantUIDs: [currentUser.id!], status: .pending)
        
        do {
            _ = try await firestoreService.createRoom(room: newRoom)
            // currentRoom و roomID و qrCodeImage سيتم تحديثها تلقائياً عن طريق الـ subscriber
            Logger.log("Room creation process started. Room ID: \(newRoom.id ?? "N/A")", level: .info)
        } catch {
            errorMessage = "Failed to create room: \(error.localizedDescription)"
            isLoading = false
            Logger.log("Error creating room: \(error.localizedDescription)", level: .error)
        }
    }

    @MainActor // تأكد من أن هذه الدوال تعمل على الـ Main Actor
    func joinRoom(with id: String) async {
        guard let currentUser = authService.user else {
            errorMessage = "User not logged in."
            Logger.log("Error joining room: User not logged in.", level: .error)
            return
        }
        
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Room ID cannot be empty."
            Logger.log("Error joining room: Room ID cannot be empty.", level: .error)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await firestoreService.joinRoom(roomID: id, participantUserID: currentUser.id!)
            // currentRoom سيتم تحديثها تلقائياً عن طريق الـ subscriber
            Logger.log("Room join process started for ID: \(id)", level: .info)
        } catch {
            errorMessage = "Failed to join room: \(error.localizedDescription)"
            isLoading = false
            Logger.log("Error joining room: \(error.localizedDescription)", level: .error)
        }
    }
    
    // ✨ دالة جديدة: لجلب بيانات المستخدم المقابل
    @MainActor
    func fetchOpponentUser(for room: Room) async {
        guard let currentUserID = authService.user?.id else {
            opponentUser = nil
            return
        }
        
        let opponentUID = room.participantUIDs.first(where: { $0 != currentUserID })
        
        guard let uid = opponentUID else {
            opponentUser = nil
            return
        }
        
        do {
            self.opponentUser = try await firestoreService.fetchUser(uid: uid)
            Logger.log("Fetched opponent user: \(self.opponentUser?.email ?? "N/A")", level: .info)
        } catch {
            errorMessage = "Failed to fetch opponent user: \(error.localizedDescription)"
            Logger.log("Error fetching opponent user: \(error.localizedDescription)", level: .error)
            opponentUser = nil
        }
    }
    
    // ✨ دالة جديدة: لمغادرة الغرفة
    @MainActor
    func leaveCurrentRoom() async {
        guard let room = currentRoom, let userID = authService.user?.id else {
            Logger.log("Attempted to leave room, but no current room or user ID available.", level: .warning)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await firestoreService.leaveRoom(roomID: room.id!, participantUserID: userID)
            // الـ currentFirestoreRoom في Service ستصبح nil
            // مما سيؤدي إلى تحديث currentRoom هنا إلى nil عبر الـ subscriber
            // وبالتالي showConversationView ستصبح false
            Logger.log("Successfully initiated leave room for room ID: \(room.id ?? "N/A").", level: .info)
        } catch {
            errorMessage = "Failed to leave room: \(error.localizedDescription)"
            Logger.log("Error leaving room: \(error.localizedDescription)", level: .error)
        }
        isLoading = false
    }

    // ✨ دالة لإنشاء صورة QR Code من نص
    func generateQRCode(from string: String) {
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        if let outputImage = filter.outputImage {
            // قم بتوسيع الصورة قليلاً لتحسين الجودة
            let scaleX = 200 / outputImage.extent.size.width
            let scaleY = 200 / outputImage.extent.size.height
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            if let cgImage = CIContext().createCGImage(transformedImage, from: transformedImage.extent) {
                self.qrCodeImage = UIImage(cgImage: cgImage)
                return
            }
        }
        self.qrCodeImage = nil // في حالة الفشل
    }
    
    // دالة لتحديد اسم المستخدم المقابل في الغرفة - تم استبدالها بـ `opponentUser`
    // هذه الدالة لم تعد ضرورية بنفس الشكل، سنعتمد على `opponentUser` مباشرة
    // func getOpponentUserName(for room: Room) -> String? { ... }
    
    // 💡 تم إزالة دالة async المساعدة وامتداد AnyPublisher.async()
    // لأننا الآن نستخدم async/await مباشرة في FirestoreService
    // func async<T>(from publisher: AnyPublisher<T, Error>) async throws -> T { ... }
}
