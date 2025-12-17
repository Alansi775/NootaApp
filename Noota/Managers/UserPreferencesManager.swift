// Noota/Managers/UserPreferencesManager.swift
import Foundation

class UserPreferencesManager {
    static let shared = UserPreferencesManager()
    private let userDefaults = UserDefaults.standard
    
    private enum Keys: String {
        case selectedLanguage = "com.noota.selectedLanguage"
        case isDarkMode = "com.noota.isDarkMode"
        case voiceProfilePrefix = "com.noota.voiceProfile"
    }
    
    // MARK: - Language Preferences
    
    var selectedLanguage: String {
        get {
            if let saved = userDefaults.string(forKey: Keys.selectedLanguage.rawValue) {
                return saved
            }
            
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            let supportedLanguages = ["en", "ar", "tr", "es", "fr", "de", "it", "pt", "zh", "ja", "ko"]
            
            if supportedLanguages.contains(systemLanguage) {
                return systemLanguage
            }
            return "en"
        }
        set {
            userDefaults.set(newValue, forKey: Keys.selectedLanguage.rawValue)
            Logger.log("Language preference set to: \(newValue)", level: .info)
        }
    }
    
    // MARK: - Theme Preferences
    
    var isDarkMode: Bool {
        get {
            userDefaults.bool(forKey: Keys.isDarkMode.rawValue)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.isDarkMode.rawValue)
            Logger.log("Dark mode: \(newValue)", level: .info)
        }
    }
    
    // MARK: - Voice Profile Management
    
    func hasVoiceProfile(for userId: String) -> Bool {
        let key = "\(Keys.voiceProfilePrefix.rawValue)_\(userId)"
        return userDefaults.bool(forKey: key)
    }
    
    func setVoiceProfile(_ hasProfile: Bool, for userId: String) {
        let key = "\(Keys.voiceProfilePrefix.rawValue)_\(userId)"
        userDefaults.set(hasProfile, forKey: key)
        Logger.log("Voice profile status for \(userId) set to: \(hasProfile)", level: .info)
    }
    
    // MARK: - Clear All Preferences
    
    func resetAllPreferences() {
        if let bundleID = Bundle.main.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: bundleID)
        }
        Logger.log("All preferences reset", level: .info)
    }
}
