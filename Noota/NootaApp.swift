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
    @StateObject var translationService = TranslationService()
    @StateObject var textToSpeechService = TextToSpeechService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(firestoreService)
                .environmentObject(speechManager)
                .environmentObject(translationService)
                .environmentObject(textToSpeechService)
        }
    }
}
