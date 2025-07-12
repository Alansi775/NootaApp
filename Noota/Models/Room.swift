import Foundation
import FirebaseFirestore

struct Room: Identifiable, Codable, Equatable {
    // ✨ إضافة enum لتوحيد حالات الغرفة
    enum Status: String, Codable { // تأكد من وجود ": String, Codable"
        case pending = "pending"
        case active = "active"
        case ended = "ended"
    }

    @DocumentID var id: String?
    let hostUserID: String
    var participantUIDs: [String]
    var status: Status // ✨ تأكد أن هذا هو Room.Status وليس String
    var createdAt: Timestamp

    var activeSpeakerUID: String?

    init(id: String? = nil, hostUserID: String, participantUIDs: [String]? = nil, status: Status = .pending, createdAt: Timestamp? = nil, activeSpeakerUID: String? = nil) {
        self.id = id
        self.hostUserID = hostUserID
        var initialParticipants = participantUIDs ?? []
        if !initialParticipants.contains(hostUserID) {
            initialParticipants.append(hostUserID)
        }
        self.participantUIDs = initialParticipants
        self.status = status
        self.createdAt = createdAt ?? Timestamp(date: Date())
        self.activeSpeakerUID = activeSpeakerUID
    }

    static func == (lhs: Room, rhs: Room) -> Bool {
        lhs.id == rhs.id &&
        lhs.hostUserID == rhs.hostUserID &&
        lhs.participantUIDs == rhs.participantUIDs &&
        lhs.status == rhs.status && // تأكد من المقارنة كـ enum
        lhs.createdAt == rhs.createdAt &&
        lhs.activeSpeakerUID == rhs.activeSpeakerUID
    }
}
