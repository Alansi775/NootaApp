// Noota/ViewModels/SettingsViewModel.swift
import Foundation
import AVFoundation
import Combine
import FirebaseFirestore

class SettingsViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var userName: String = ""
    @Published var hasVoiceProfile: Bool = false
    @Published var selectedLanguage: String = "en"
    @Published var isDarkMode: Bool = false
    
    let availableLanguages = ["en", "ar", "tr", "es", "fr", "de", "it", "pt", "zh", "ja", "ko"]
    
    private var authService: AuthService
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let userDefaults = UserDefaults.standard
    
    init(authService: AuthService) {
        self.authService = authService
        super.init()
        loadUserData()
        loadPreferences()
        checkVoiceProfile()
    }
    
    // MARK: - User Data Management
    
    private func loadUserData() {
        if let user = authService.user {
            userName = user.firstName ?? user.email ?? "User"
        }
    }
    
    func updateUserName(_ newName: String) {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard var user = authService.user else { return }
        
        Task {
            do {
                // Update the user object locally first
                user.firstName = newName
                
                // Update in Firestore via AuthService
                let db = Firestore.firestore()
                try await db.collection("users").document(user.uid).updateData([
                    "firstName": newName
                ])
                
                DispatchQueue.main.async {
                    self.userName = newName
                    self.authService.user?.firstName = newName
                    Logger.log("User name updated to: \(newName)", level: .info)
                }
            } catch {
                Logger.log("Error updating user name: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    // MARK: - Language Management
    
    func getLanguageName(_ code: String) -> String {
        let names: [String: String] = [
            "en": "English",
            "ar": "العربية",
            "tr": "Türkçe",
            "es": "Español",
            "fr": "Français",
            "de": "Deutsch",
            "it": "Italiano",
            "pt": "Português",
            "zh": "中文",
            "ja": "日本語",
            "ko": "한국어"
        ]
        return names[code] ?? code
    }
    
    func saveLanguagePreference(_ language: String) {
        UserPreferencesManager.shared.selectedLanguage = language
        DispatchQueue.main.async {
            self.selectedLanguage = language
            Logger.log("Language preference saved: \(language)", level: .info)
        }
    }
    
    private func loadPreferences() {
        selectedLanguage = UserPreferencesManager.shared.selectedLanguage
        isDarkMode = UserPreferencesManager.shared.isDarkMode
    }
    
    // MARK: - Theme Management
    
    func setDarkMode(_ isDark: Bool) {
        UserPreferencesManager.shared.isDarkMode = isDark
        DispatchQueue.main.async {
            self.isDarkMode = isDark
            Logger.log("Dark mode: \(isDark)", level: .info)
        }
    }
    
    // MARK: - Voice Profile Management
    
    private func checkVoiceProfile() {
        guard let userId = authService.user?.id else { return }
        hasVoiceProfile = UserPreferencesManager.shared.hasVoiceProfile(for: userId)
    }
    
    func getVoiceRegistrationText(for language: String) -> String {
        let texts: [String: String] = [
            "en": "Hello, my name is and I am speaking in English. This is my voice profile for the Noota translation application. I will use this voice profile to communicate with people who speak different languages. Thank you for listening to my voice. This recording will help me connect with others around the world.",
            "ar": "السلام عليكم، أنا أتحدث باللغة العربية. هذا ملف صوتي شخصي لتطبيق نوتا للترجمة الفورية. سيتم استخدام هذا الملف الصوتي ليتمكن الآخرون من سماع صوتي باللغات المختلفة. شكراً لاستماعك إلى صوتي. هذا التسجيل سيساعدني على التواصل مع الأشخاص حول العالم.",
            "tr": "Merhaba, Türkçe konuşuyorum. Bu, Noota çeviri uygulaması için kişisel bir ses profilim. Bu ses profili, diğer insanların sesimi farklı dillerde duymasını sağlayacaktır. Sesimi dinlediğiniz için teşekkür ederim. Bu kayıt, dünya çapındaki diğer insanlarla iletişim kurmama yardımcı olacaktır.",
            "es": "Hola, estoy hablando en español. Este es mi perfil de voz personal para la aplicación de traducción Noota. Este perfil de voz permitirá que otras personas escuchen mi voz en diferentes idiomas. Gracias por escuchar mi voz. Esta grabación me ayudará a comunicarme con personas de todo el mundo.",
            "fr": "Bonjour, je parle en français. Ceci est mon profil vocal personnel pour l'application de traduction Noota. Ce profil vocal permettra à d'autres personnes d'entendre ma voix dans différentes langues. Merci d'avoir écouté ma voix. Cet enregistrement m'aidera à communiquer avec des personnes du monde entier.",
            "de": "Hallo, ich spreche auf Deutsch. Dies ist mein persönliches Sprachprofil für die Noota-Übersetzungsanwendung. Dieses Sprachprofil ermöglicht es anderen Personen, meine Stimme in verschiedenen Sprachen zu hören. Danke, dass du mir zuhört. Diese Aufnahme hilft mir, mit Menschen auf der ganzen Welt zu kommunizieren.",
            "it": "Ciao, sto parlando in italiano. Questo è il mio profilo vocale personale per l'applicazione di traduzione Noota. Questo profilo vocale permetterà ad altre persone di ascoltare la mia voce in lingue diverse. Grazie per aver ascoltato la mia voce. Questa registrazione mi aiuterà a comunicare con persone in tutto il mondo.",
            "pt": "Olá, estou falando em português. Este é meu perfil de voz pessoal para o aplicativo de tradução Noota. Este perfil de voz permitirá que outras pessoas ouçam minha voz em diferentes idiomas. Obrigado por ouvir minha voz. Esta gravação me ajudará a me comunicar com pessoas em todo o mundo.",
            "zh": "你好，我用中文说话。这是我为Noota翻译应用程序的个人语音档案。此语音档案将使其他人能够用不同的语言听到我的声音。感谢您听我的声音。这条记录将帮助我与世界各地的人们交流。",
            "ja": "こんにちは、日本語で話しています。これはNoota翻訳アプリケーション用の個人的な音声プロファイルです。この音声プロファイルにより、他の人が異なる言語で私の声を聞くことができます。私の声を聞いてくれてありがとうございます。この記録は、世界中の人々と交流するのに役立ちます。",
            "ko": "안녕하세요, 저는 한국어로 말하고 있습니다. 이것은 Noota 번역 애플리케이션을 위한 개인 음성 프로필입니다. 이 음성 프로필을 통해 다른 사람들이 다양한 언어로 제 목소리를 들을 수 있습니다. 제 목소리를 들어주셔서 감사합니다. 이 녹음은 전 세계 사람들과 소통하는 데 도움이 될 것입니다."
        ]
        
        return texts[language] ?? texts["en"] ?? "Please read this text clearly."
    }
    
    // MARK: - Voice Recording
    
    func startVoiceRecording(language: String) {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.record, mode: .default, options: [])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let docDirectory = documents[0]
            let audioFilename = docDirectory.appendingPathComponent("voice_profile_\(language).wav")
            recordingURL = audioFilename
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            Logger.log("Voice recording started for language: \(language)", level: .info)
        } catch {
            Logger.log("Error starting voice recording: \(error.localizedDescription)", level: .error)
        }
    }
    
    func stopVoiceRecording() {
        audioRecorder?.stop()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Logger.log("Error deactivating audio session: \(error.localizedDescription)", level: .error)
        }
        
        Logger.log("Voice recording stopped", level: .info)
    }
    
    func uploadVoiceProfile(language: String) async throws {
        guard let recordingURL = recordingURL,
              let userId = authService.user?.id else {
            throw NSError(domain: "SettingsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing user ID or recording URL"])
        }
        
        // Read audio file data
        let audioData = try Data(contentsOf: recordingURL)
        Logger.log("📤 Voice profile upload starting for user: \(userId), Language: \(language), Audio size: \(audioData.count) bytes", level: .info)
        
        // Create multipart form data
        // Use Bonjour hostname for real device compatibility (works on both simulator and real device)
        var request = URLRequest(url: URL(string: "http://Mustafa-iMac.local:5001/api/voice-profiles/upload")!)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add user ID field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)
        Logger.log(" Added userId field: \(userId)", level: .debug)
        
        // Add language field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(language)\r\n".data(using: .utf8)!)
        Logger.log(" Added language field: \(language)", level: .debug)
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"voice_profile.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        Logger.log(" Added audio file: \(audioData.count) bytes", level: .debug)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        Logger.log("📡 Sending request to: http://Mustafa-iMac.local:5001/api/voice-profiles/upload", level: .info)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.log(" Invalid response type", level: .error)
            throw NSError(domain: "SettingsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        Logger.log("📊 Response status code: \(httpResponse.statusCode)", level: .info)
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.log(" Upload failed: \(errorMsg)", level: .error)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SettingsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload failed"])
        }
        
        DispatchQueue.main.async {
            guard let userId = self.authService.user?.id else { return }
            UserPreferencesManager.shared.setVoiceProfile(true, for: userId)
            self.hasVoiceProfile = true
            Logger.log(" Voice profile uploaded successfully for user: \(userId)", level: .info)
        }
        
        // Clean up recording file
        try? FileManager.default.removeItem(at: recordingURL)
        Logger.log("🗑️ Cleaned up local recording file", level: .debug)
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            Logger.log("Audio recording finished successfully", level: .info)
        } else {
            Logger.log("Audio recording failed", level: .error)
        }
    }
}
