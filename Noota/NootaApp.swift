// Noota/NootaApp.swift

import SwiftUI
import FirebaseCore
import Firebase

@main
struct NootaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject var authService = AuthService()
    @StateObject var firestoreService = FirestoreService()
    @StateObject var speechManager = SpeechManager()
    @StateObject var textToSpeechService = TextToSpeechService()
    
    //  1. تهيئة GeminiService أولاً (خدمة مستقلة)
    @StateObject var geminiService = GeminiService()
    
    //  2. تهيئة TranslationService معتمدًا على GeminiService
    @StateObject var translationService: TranslationService

    init() {
        // ... (تكوين Firebase هنا) ...
        
        //  ربط الترجمة بخدمة Gemini (مع إنشاء نسخة جديدة داخل init)
        _translationService = StateObject(wrappedValue: TranslationService(geminiService: GeminiService()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(firestoreService)
                .environmentObject(speechManager)
                .environmentObject(translationService)
                .environmentObject(textToSpeechService)
                .environmentObject(geminiService)
        }
    }
}
