// Noota/Services/TextToSpeechService.swift

import Foundation
import AVFoundation // Required for AVSpeechSynthesizer
import Combine

class TextToSpeechService: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks the given text in the specified language.
    /// - Parameters:
    ///   - text: The text to be spoken.
    ///   - languageCode: The language code (e.g., "en-US", "ar-SA") for the speech.
    func speak(text: String, languageCode: String) {
        // Ensure there's no ongoing speech to avoid overlap
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        
        // Optional: Adjust speech parameters for better quality
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate // Default speed
        utterance.pitchMultiplier = 1.0 // Normal pitch
        utterance.volume = 1.0 // Full volume
        
        synthesizer.speak(utterance)
        Logger.log("TextToSpeechService: Speaking '\(text)' in '\(languageCode)'", level: .info)
    }

    /// Stops any ongoing speech immediately.
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            Logger.log("TextToSpeechService: Stopped speaking.", level: .info)
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate (Optional, but good for logging/status)
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Logger.log("TextToSpeechService: Started speaking: '\(utterance.speechString)'", level: .debug)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Logger.log("TextToSpeechService: Finished speaking: '\(utterance.speechString)'", level: .debug)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Logger.log("TextToSpeechService: Paused speaking: '\(utterance.speechString)'", level: .debug)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Logger.log("TextToSpeechService: Continued speaking: '\(utterance.speechString)'", level: .debug)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Logger.log("TextToSpeechService: Canceled speaking: '\(utterance.speechString)'", level: .debug)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // This delegate method can be used to highlight words as they are spoken
        // Logger.log("TextToSpeechService: Will speak range \(characterRange) of '\(utterance.speechString)'", level: .debug)
    }
}
