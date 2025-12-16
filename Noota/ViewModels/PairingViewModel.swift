import Foundation
import Combine
import FirebaseFirestore
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

class PairingViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentRoom: Room?
    @Published var roomID: String = "" // This will now be directly set upon creation/join
    @Published var qrCodeImage: UIImage?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var isDataFullyLoadedForConversation: Bool = false
    
    @Published var showConversationView: Bool = false
    @Published var opponentUser: User?
    @Published var conversationViewModel: ConversationViewModel?
    
    // MARK: - Services

    let firestoreService: FirestoreService
    let authService: AuthService
    
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(firestoreService: FirestoreService, authService: AuthService) {
        self.firestoreService = firestoreService
        self.authService = authService
        
        // This sink reacts to changes in `currentFirestoreRoom` from FirestoreService.
        // It's responsible for updating the ViewModel's state based on real-time database changes.
        firestoreService.$currentFirestoreRoom
            .receive(on: DispatchQueue.main) // Ensure UI updates on the main thread
            .sink { [weak self] room in
                guard let self = self else { return }
                
                // Update properties based on the observed room
                self.currentRoom = room
                self.roomID = room?.id ?? ""
                
                if let id = room?.id {
                    self.generateQRCode(from: id) // Generate QR code if room ID exists
                } else {
                    self.qrCodeImage = nil // Clear QR code if no room
                }
                
                Task { @MainActor in
                    if let activeRoom = room, activeRoom.status == .active && activeRoom.participantUIDs.count == 2 {
                        Logger.log("Detected active room with 2 participants. Room ID: \(activeRoom.id ?? "N/A")", level: .info)
                        await self.handleRoomActiveState(activeRoom: activeRoom)
                    } else {
                        self.isDataFullyLoadedForConversation = false
                        self.showConversationView = false
                        self.opponentUser = nil
                        
                        if room == nil {
                            Logger.log("currentFirestoreRoom became nil. showConversationView set to false.", level: .info)
                        } else {
                            Logger.log("Room \(room?.id ?? "N/A") status: \(room?.status.rawValue ?? "N/A"). Waiting for opponent or active status.", level: .info)
                        }
                    }
                    // Do NOT set isLoading to false here, as it might be set by createNewRoom/joinRoom
                    // isLoading should be managed by the specific async functions
                }
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Room Management Functions

    @MainActor
    func createNewRoom() async {
        guard let currentUser = authService.user else {
            errorMessage = "User not logged in."
            Logger.log("Error creating room: User not logged in.", level: .error)
            return
        }
        
        isLoading = true // Start loading state
        errorMessage = nil

        // Create a new Room object with initial pending status
        // The ID will be assigned by FirestoreService
        let newRoom = Room(hostUserID: currentUser.id!, participantUIDs: [currentUser.id!], status: .pending)
        
        do {
            // Call createRoom on FirestoreService.
            // Assuming this function now returns the created Room object *with its Firestore ID*.
            let createdRoom = try await firestoreService.createRoom(room: newRoom)
            
            // Immediately update the published properties in the ViewModel
            // This ensures the UI updates right away with the new room's info
            self.currentRoom = createdRoom
            self.roomID = createdRoom.id ?? ""
            self.generateQRCode(from: self.roomID) // Generate QR for the newly created room ID
            
            Logger.log("Room created successfully with ID: \(createdRoom.id ?? "N/A")", level: .info)
            
        } catch {
            errorMessage = "Failed to create room: \(error.localizedDescription)"
            Logger.log("Error creating room: \(error.localizedDescription)", level: .error)
            // It's important to set currentRoom/roomID/qrCodeImage to nil if creation fails
            self.currentRoom = nil
            self.roomID = ""
            self.qrCodeImage = nil
        }
        isLoading = false // End loading state
    }

    @MainActor
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
        
        isLoading = true // Start loading state
        errorMessage = nil
        
        // Call joinRoom on FirestoreService
        do {
            let room = try await firestoreService.joinRoom(roomID: id, participantUserID: currentUser.id!)
            Logger.log("Successfully joined room: \(room.id ?? "unknown")", level: .info)
        } catch {
            errorMessage = "Failed to join room: \(error.localizedDescription)"
            Logger.log("Error joining room: \(error.localizedDescription)", level: .error)
        }
        
        // The `firestoreService.$currentFirestoreRoom` sink will now handle updating
        // `self.currentRoom`, `self.roomID`, and `self.qrCodeImage` once Firestore confirms the join.
        
        isLoading = false // End loading state
    }
    
    @MainActor
    func leaveCurrentRoom() async {
        guard let room = currentRoom, let userID = authService.user?.id else {
            Logger.log("Attempted to leave room, but no current room or user ID available.", level: .warning)
            return
        }
        
        isLoading = true // Start loading state
        errorMessage = nil
        
        do {
            try await firestoreService.leaveRoom(roomID: room.id!, participantUserID: userID)
            // The FirestoreService.$currentFirestoreRoom sink will handle setting currentRoom to nil
            // and consequently updating roomID and qrCodeImage.
            Logger.log("Successfully initiated leave room for room ID: \(room.id ?? "N/A").", level: .info)
        } catch {
            errorMessage = "Failed to leave room: \(error.localizedDescription)"
            Logger.log("Error leaving room: \(error.localizedDescription)", level: .error)
        }
        isLoading = false // End loading state
    }

    // MARK: - Helper Functions

    @MainActor
    private func handleRoomActiveState(activeRoom: Room) async {
        let currentUserID = self.authService.user?.id
        let opponentID = activeRoom.participantUIDs.first(where: { $0 != currentUserID })
        
        guard let validOpponentID = opponentID else {
            Logger.log("Room \(activeRoom.id ?? "N/A") is active, but opponent ID not found yet (currentUserID: \(currentUserID ?? "nil")). Retrying on next update.", level: .warning)
            self.opponentUser = nil
            self.isDataFullyLoadedForConversation = false
            self.showConversationView = false
            return
        }
        
        do {
            let opponent = try await self.firestoreService.fetchUser(uid: validOpponentID)
            self.opponentUser = opponent
            
            if self.currentRoom != nil && self.authService.user != nil && self.opponentUser != nil {
                self.isDataFullyLoadedForConversation = true
                self.showConversationView = true
                Logger.log("Room \(activeRoom.id ?? "N/A") is active, opponent fetched, and all data loaded. showConversationView set to true.", level: .info)
            } else {
                Logger.log("Conversation data not fully ready after fetching opponent. Some data is nil. Room: \(self.currentRoom != nil), CurrentUser: \(self.authService.user != nil), OpponentUser: \(self.opponentUser != nil)", level: .error)
                self.isDataFullyLoadedForConversation = false
                self.showConversationView = false
            }
            
        } catch {
            self.errorMessage = "Failed to fetch opponent user: \(error.localizedDescription)"
            Logger.log("Error fetching opponent user in handleRoomActiveState: \(error.localizedDescription)", level: .error)
            self.opponentUser = nil
            self.isDataFullyLoadedForConversation = false
            self.showConversationView = false
        }
    }

    // This function generates the QR code.
    // It is called by the `currentFirestoreRoom` sink and directly by `createNewRoom`.
    func generateQRCode(from string: String) {
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        if let outputImage = filter.outputImage {
            // Scale up the image for better resolution
            let transform = CGAffineTransform(scaleX: 10, y: 10) // Scale factor for better quality
            let scaledCIImage = outputImage.transformed(by: transform)
            
            let context = CIContext()
            if let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) {
                // Ensure this assignment happens on the main thread if called from a background context.
                // Since this is called from `sink` which uses `receive(on: .main)` and `createNewRoom`
                // is `@MainActor`, it should be fine.
                self.qrCodeImage = UIImage(cgImage: cgImage)
                return
            }
        }
        self.qrCodeImage = nil
    }
    
    @MainActor
    func resetPairingState() {
        self.currentRoom = nil
        self.roomID = ""
        self.qrCodeImage = nil
        self.errorMessage = nil
        self.isLoading = false
        self.isDataFullyLoadedForConversation = false
        self.showConversationView = false
        self.opponentUser = nil
        Logger.log("PairingViewModel state reset.", level: .info)
    }
}
