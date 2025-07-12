// Noota/Models/AppError.swift
import Foundation

enum AppError: LocalizedError {
    case authenticationError(String)
    case firestoreError(String)
    case networkError(String)
    case customError(String)
    case inputError(String)
    case validationError(String)

    var errorDescription: String? {
        switch self {
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        case .firestoreError(let message):
            return "Firestore Error: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .customError(let message):
            return "Error: \(message)"
        case .inputError(let message):
            return "Input Error: \(message)"
        case .validationError(let message):
            return "Validation Error: \(message)"
        }
    }
}
