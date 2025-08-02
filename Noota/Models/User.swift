// Noota/Models/User.swift هذا
import Foundation
import FirebaseFirestore

// أضف Hashable هنا (إذا لم تكن مضافة بالفعل)
struct User: Identifiable, Codable, Equatable, Hashable {
    @DocumentID var id: String?
    let uid: String
    let email: String?
    var firstName: String?
    var lastName: String?
    var displayName: String?
    var currentRoomId: String?
    var preferredVoiceGender: String?
    var userLanguageCode: String?
    
    // ✨ إضافة خاصية `username`
    // يمكن أن تكون هذه هي firstName أو displayName، أو أي اسم تفضله للعرض
    // يمكن تعيينها يدوياً أو حسابها من firstName/lastName عند الإنشاء
    var username: String?
    
    // ✨ إضافة خاصية `preferredLanguageCode`
    // هذه هي اللغة التي يفضلها المستخدم للترتعلى الكلام والنطق
    var preferredLanguageCode: String?

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
        
        // ✨ عند التهيئة، يمكن تعيين `username` ليكون هو `displayName` أو `firstName`
        // اختر ما يناسبك بناءً على كيفية استخدام هذه الخاصية في مشروعك
        self.username = self.displayName ?? self.firstName ?? email
        
        // ✨ إذا كان `userLanguageCode` هو نفسه `preferredLanguageCode`، قم بتعيينه
        self.preferredLanguageCode = self.userLanguageCode
    }
    
    // مُهيئ إضافي (اختياري) إذا كنت تريد إنشاء المستخدم مباشرة بـ `username` و `preferredLanguageCode`
    // هذا سيوفر عليك الحاجة إلى حسابها من firstName/lastName في كل مرة.
    init(uid: String, email: String?, username: String?, preferredLanguageCode: String?, currentRoomId: String? = nil, preferredVoiceGender: String? = nil) {
        self.uid = uid
        self.id = uid
        self.email = email
        self.username = username
        self.preferredLanguageCode = preferredLanguageCode
        self.currentRoomId = currentRoomId
        self.preferredVoiceGender = preferredVoiceGender
        
        // الخصائص القديمة يمكن أن تظل nil أو تُعين بقيم افتراضية إذا كانت مطلوبة من أجزاء أخرى
        self.firstName = nil
        self.lastName = nil
        self.displayName = username
        self.userLanguageCode = preferredLanguageCode
    }
    
    // Equatable - لا يزال مطلوبًا لـ Hashable
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.uid == rhs.uid
    }

    // Hashable - Swift سيولد هذا تلقائياً إذا كانت كل الخصائص Hashable.
    // بما أن جميع الخصائص (uid, email, firstName, إلخ) هي String? أو String أو Bool، فإنها Hashable.
    // لا تحتاج إلى تطبيق يدوي إلا إذا كان لديك منطق تجزئة معقد وتريد التحكم فيه (باستخدام UID فقط للتجزئة).
    /*
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    */
}
