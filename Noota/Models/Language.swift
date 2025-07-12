// Noota/Models/Language.swift
import Foundation
import NaturalLanguage // لاستخدام NLLanguage

struct Language: Identifiable, Codable, Hashable {
    let id = UUID() // معرف فريد لكل لغة
    let name: String // اسم اللغة (مثلاً: "English", "Arabic")
    let appleLocaleIdentifier: String // معرف اللغة لتطبيق Apple Translation (مثلاً: "en-US", "ar-SA")
    let googleCloudCode: String // رمز اللغة لخدمة Google Cloud (مثلاً: "en", "ar")
    let nlLanguageCode: NLLanguage // رمز اللغة لـ NaturalLanguage framework (مثلاً: .english, .arabic)

    // تعريف مفاتيح الترميز/فك الترميز (CodingKeys)
    enum CodingKeys: String, CodingKey {
        case name
        case appleLocaleIdentifier
        case googleCloudCode
        // nlLanguageCode لا نضعها هنا لأنها ليست Codable بشكل تلقائي
    }

    // Initializer مخصص لـ Decodable (عند فك ترميز البيانات من Firestore/JSON)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.appleLocaleIdentifier = try container.decode(String.self, forKey: .appleLocaleIdentifier)
        self.googleCloudCode = try container.decode(String.self, forKey: .googleCloudCode)

        // هنا نقوم بإنشاء nlLanguageCode يدوياً بناءً على appleLocaleIdentifier
        // تأكد من أن NLLanguage(rawValue:) يمكنه تحويل appleLocaleIdentifier إلى NLLanguage
        // أو استخدم googleCloudCode إذا كان أفضل
        self.nlLanguageCode = NLLanguage(rawValue: self.appleLocaleIdentifier.prefix(2).lowercased()) ?? .undetermined

        // إذا كان الـ id الخاص بك هو UUID، فسيتم إنشاؤه تلقائيًا
        // أو يمكنك فك ترميزه إذا كان مخزنًا في البيانات
        // self.id = try container.decode(UUID.self, forKey: .id) // إذا كان UUID مخزناً
    }

    // دالة ترميز مخصصة لـ Encodable (عند ترميز البيانات لحفظها في Firestore/JSON)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(appleLocaleIdentifier, forKey: .appleLocaleIdentifier)
        try container.encode(googleCloudCode, forKey: .googleCloudCode)
        // لا نُرمّز nlLanguageCode لأنها ليست Codable
    }

    // Initializer الأصلي لاستخدامه عند إنشاء كائنات Language يدوياً في الكود
    init(name: String, appleLocaleIdentifier: String, googleCloudCode: String, nlLanguageCode: NLLanguage) {
        self.name = name
        self.appleLocaleIdentifier = appleLocaleIdentifier
        self.googleCloudCode = googleCloudCode
        self.nlLanguageCode = nlLanguageCode
        // الـ id سيتم تعيينه تلقائياً بواسطة UUID() في خصائص الـ struct
    }

    static let english = Language(name: "English", appleLocaleIdentifier: "en-US", googleCloudCode: "en", nlLanguageCode: .english)
    static let arabic = Language(name: "Arabic", appleLocaleIdentifier: "ar-SA", googleCloudCode: "ar", nlLanguageCode: .arabic)
    // أضف المزيد من اللغات حسب الحاجة

    // مثال على قائمة بجميع اللغات المدعومة
    static let allLanguages: [Language] = [.english, .arabic]
}
