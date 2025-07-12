// Noota/NootaApp.swift
import SwiftUI
import FirebaseCore
import Firebase


@main
struct NootaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
        }
    }
}
