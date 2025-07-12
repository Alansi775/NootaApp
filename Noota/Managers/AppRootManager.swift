// Noota/Managers/AppRootManager.swift
import Foundation
import Combine

enum AppNavigationPath: Hashable {
    case authentication
    case pairing
    case room(roomID: String, currentUser: User) // تأكد أن User الآن Hashable
    case home
}

class AppRootManager: ObservableObject {
    @Published var currentView: AppNavigationPath

    init() {
        self.currentView = .authentication
    }
}
