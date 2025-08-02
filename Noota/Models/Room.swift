import Foundation
import FirebaseFirestore // For Timestamp


struct Room: Identifiable, Codable, Equatable {
    // Enum for Room Status
    enum Status: String, Codable {
        case pending = "pending" // Room created, waiting for opponent
        case active = "active"   // Two participants are in the room, conversation can start
        case ended = "ended"     // Room is no longer active (e.g., deleted or all left)
    }

    // MARK: - Properties

    // @DocumentID automatically handles mapping the Firestore document ID to this property
    @DocumentID var id: String?

    let hostUserID: String // The UID of the user who created the room

    // participantUIDs should be mutable (`var`) because it changes when users join/leave
    var participantUIDs: [String]

    // Status should be mutable (`var`) as it changes (pending -> active -> ended)
    var status: Status

    // createdAt should be a Timestamp
    let createdAt: Timestamp // Make this `let` as it's typically set once

    var activeSpeakerUID: String? // Optional, mutable for real-time speaker tracking

    // participantLanguages needs to be mutable (`var`) and an optional dictionary
    // If it's nil initially, Firebase will store it as a null field, or an empty map {}
    // when you add the first language.
    var participantLanguages: [String: String]?

    // MARK: - Initialization

    init(id: String? = nil,
         hostUserID: String,
         participantUIDs: [String]? = nil,
         status: Status = .pending,
         createdAt: Timestamp? = nil,
         activeSpeakerUID: String? = nil,
         participantLanguages: [String: String]? = nil) {

        self.id = id
        self.hostUserID = hostUserID

        // Initialize participantUIDs:
        // Start with provided UIDs or an empty array.
        // Ensure the host's UID is always included if not already present.
        var initialParticipants = participantUIDs ?? []
        if !initialParticipants.contains(hostUserID) {
            initialParticipants.append(hostUserID)
        }
        self.participantUIDs = initialParticipants

        self.status = status
        self.createdAt = createdAt ?? Timestamp(date: Date()) // Use current date if not provided
        self.activeSpeakerUID = activeSpeakerUID

        // Initialize participantLanguages:
        // Use provided dictionary or an empty dictionary if you always want it present (even if empty).
        // If you want it to be truly optional (can be nil), keep it as `participantLanguages`.
        // I'd recommend initializing it to an empty dictionary `[:]` rather than `nil` for consistency,
        // unless you specifically need the Firestore field to be absent when no languages are present.
        self.participantLanguages = participantLanguages ?? [:] // Changed to default to empty dictionary
    }
    
    // MARK: - Equatable Conformance

    static func == (lhs: Room, rhs: Room) -> Bool {
        // Compare all properties for equality
        lhs.id == rhs.id &&
        lhs.hostUserID == rhs.hostUserID &&
        lhs.participantUIDs == rhs.participantUIDs &&
        lhs.status == rhs.status &&
        lhs.createdAt == rhs.createdAt &&
        lhs.activeSpeakerUID == rhs.activeSpeakerUID &&
        lhs.participantLanguages == rhs.participantLanguages
    }
}
