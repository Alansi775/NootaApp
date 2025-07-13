// Noota/Models/Room.swift
import Foundation
import FirebaseFirestore

struct Room: Identifiable, Codable, Equatable {
    enum Status: String, Codable {
        case pending = "pending"
        case active = "active"
        case ended = "ended"
    }

    @DocumentID var id: String?
    let hostUserID: String
    var participantUIDs: [String]
    var status: Status
    var createdAt: Timestamp
    
    var activeSpeakerUID: String?
    
    // ✨ إضافة قاموس لتخزين لغة كل مشارك
    // المفتاح: UID الخاص بالمستخدم، القيمة: كود اللغة (مثل "en", "ar", "tr")
    var participantLanguages: [String: String]? // جعلها اختيارية في البداية

    init(id: String? = nil, hostUserID: String, participantUIDs: [String]? = nil, status: Status = .pending, createdAt: Timestamp? = nil, activeSpeakerUID: String? = nil, participantLanguages: [String: String]? = nil) {
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
        self.participantLanguages = participantLanguages // تهيئة الخاصية الجديدة
    }
    
    static func == (lhs: Room, rhs: Room) -> Bool {
        lhs.id == rhs.id &&
        lhs.hostUserID == rhs.hostUserID &&
        lhs.participantUIDs == rhs.participantUIDs &&
        lhs.status == rhs.status &&
        lhs.createdAt == rhs.createdAt &&
        lhs.activeSpeakerUID == rhs.activeSpeakerUID &&
        lhs.participantLanguages == rhs.participantLanguages // ✨ إضافة مقارنة الخاصية الجديدة
    }
}
