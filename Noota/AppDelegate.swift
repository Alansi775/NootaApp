// Noota/AppDelegate.swift
import UIKit
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        // Logger.setup() // ✨ علّق هذا السطر أو احذفه تمامًا
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        var handled: Bool

        if GIDSignIn.sharedInstance.handle(url) {
            handled = true
        } else {
            handled = false
        }
        return handled
    }
}
