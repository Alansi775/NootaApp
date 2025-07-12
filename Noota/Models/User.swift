// Noota/Models/User.swift
import Foundation
import FirebaseFirestore

// ✨ أضف Hashable هنا
struct User: Identifiable, Codable, Equatable, Hashable { // ✨ تأكد من إضافة Hashable
    @DocumentID var id: String?
    let uid: String
    let email: String?
    var firstName: String?
    var lastName: String?
    var displayName: String?
    var currentRoomId: String?
    var preferredVoiceGender: String?
    var userLanguageCode: String? 

    init(uid: String, email: String?, firstName: String?, lastName: String?, currentRoomId: String? = nil, preferredVoiceGender: String? = nil) {
        self.uid = uid
        self.id = uid
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.currentRoomId = currentRoomId
        self.preferredVoiceGender = preferredVoiceGender
        
        let combinedName = (firstName ?? "") + " " + (lastName ?? "")
        self.displayName = combinedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : combinedName
    }
    
    // Equatable - لا يزال مطلوبًا لـ Hashable
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.uid == rhs.uid
    }

    // ✨ Hashable - Swift سيولد هذا تلقائياً إذا كانت كل الخصائص Hashable.
    // لكن يمكنك توفير تطبيق يدوي إذا أردت التحكم في ذلك (على سبيل المثال، باستخدام UID فقط للتجزئة)
    /*
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    */
}
