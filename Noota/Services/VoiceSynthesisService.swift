// Noota/Services/VoiceSynthesisService.swift
import Foundation
import Combine

class VoiceSynthesisService: NSObject, ObservableObject {
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0
    
    private let xttsServerURL: String
    private let firestoreService: FirestoreService
    
    init(firestoreService: FirestoreService, xttsServerURL: String = "http://localhost:8000") {
        self.firestoreService = firestoreService
        self.xttsServerURL = xttsServerURL
        super.init()
    }
    
    func generateSpeech(
        text: String,
        userId: String,
        language: String
    ) async throws -> Data {
        isGenerating = true
        generationProgress = 0
        
        defer { isGenerating = false }
        
        do {
            // Step 1: Get user's voice profile path
            generationProgress = 0.2
            let voiceProfilePath = try await getVoiceProfilePath(for: userId)
            
            guard !voiceProfilePath.isEmpty else {
                throw NSError(
                    domain: "VoiceSynthesisService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "User has no voice profile"]
                )
            }
            
            // Step 2: Prepare request
            generationProgress = 0.4
            let requestBody: [String: Any] = [
                "text": text,
                "speaker_audio_path": voiceProfilePath,
                "language": language
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Step 3: Create request
            var request = URLRequest(url: URL(string: "\(xttsServerURL)/generate")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            request.timeoutInterval = 120 // 2 minutes timeout
            
            // Step 4: Send request
            generationProgress = 0.6
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "VoiceSynthesisService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
                )
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(
                    domain: "VoiceSynthesisService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
            }
            
            generationProgress = 1.0
            Logger.log("Speech synthesis completed for text: \(text.prefix(50))...", level: .info)
            
            return data
        } catch {
            Logger.log("Speech synthesis error: \(error.localizedDescription)", level: .error)
            throw error
        }
    }
    
    private func getVoiceProfilePath(for userId: String) async throws -> String {
        do {
            // Use fetchUser method from FirestoreService
            if let user = try await firestoreService.fetchUser(uid: userId) {
                // Check if user has voiceProfilePath in their document
                // For now, return empty string - in future, store voiceProfilePath in User model
                return ""
            }
            
            return ""
        } catch {
            Logger.log("Error retrieving voice profile: \(error.localizedDescription)", level: .error)
            return ""
        }
    }
    
    func generateSpeechWithFallback(
        text: String,
        userId: String,
        language: String,
        fallbackToGeneric: Bool = true
    ) async throws -> Data {
        do {
            // Try to use user's voice profile
            return try await generateSpeech(text: text, userId: userId, language: language)
        } catch {
            if fallbackToGeneric {
                Logger.log("Voice profile synthesis failed, using generic voice", level: .warning)
                // Return empty data or default audio
                // In production, this could be a pre-recorded generic voice
                return Data()
            } else {
                throw error
            }
        }
    }
}
