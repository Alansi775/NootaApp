// Noota/Managers/SpeechManager.swift
import Foundation
import Speech
import AVFoundation
import Combine

class SpeechManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // MARK: - Private Properties

    // تم إصلاح الخطأ الثاني: تغيير 'let' إلى 'var' هنا
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine() // Manages audio input
    private var currentLocale: Locale // To hold the current locale for speech recognition

    // MARK: - Initialization

    override init() {
        // Initialize with a default locale, e.g., English (US)
        // You might want to make this configurable or based on user settings later
        currentLocale = Locale(identifier: "en-US")
        speechRecognizer = SFSpeechRecognizer(locale: currentLocale)
        super.init()
        speechRecognizer?.delegate = self // Set self as the delegate for SFSpeechRecognizer
        requestAuthorization() // Request authorization on initialization
    }

    // MARK: - Authorization

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            // Move to the main queue to update UI-related properties
            DispatchQueue.main.async {
                self.authorizationStatus = authStatus
                switch authStatus {
                case .authorized:
                    Logger.log("Speech recognition authorization granted.", level: .info)
                    self.errorMessage = nil
                case .denied:
                    self.errorMessage = "User denied speech recognition authorization."
                    Logger.log(self.errorMessage!, level: .error)
                case .restricted:
                    self.errorMessage = "Speech recognition restricted on this device."
                    Logger.log(self.errorMessage!, level: .error)
                case .notDetermined:
                    self.errorMessage = "Speech recognition authorization not determined."
                    Logger.log(self.errorMessage!, level: .warning)
                @unknown default:
                    self.errorMessage = "Unknown speech recognition authorization status."
                    Logger.log(self.errorMessage!, level: .error)
                }
            }
        }
    }

    // MARK: - Speech Recognition Control

    func startRecording() {
        guard authorizationStatus == .authorized else {
            errorMessage = "Speech recognition not authorized. Please enable it in Settings."
            Logger.log(errorMessage!, level: .error)
            return
        }

        // Stop any ongoing tasks or engine sessions
        stopRecording()

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
            // تم إصلاح الخطأ الأول: تحديد مستوى LogLevel بشكل صريح
            Logger.log(errorMessage!, level: .error)
            return
        }

        // Create a new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true // Get results as they are recognized

        // Ensure we have a speech recognizer and recognition request
        guard let speechRecognizer = speechRecognizer else {
            errorMessage = "Speech recognizer is not available for the current locale."
            Logger.log(errorMessage!, level: .error)
            return
        }
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create speech recognition request."
            Logger.log(errorMessage!, level: .error)
            return
        }

        // Start the recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
                isFinal = result.isFinal
                Logger.log("Transcribing: \(self.transcribedText)", level: .debug)
            }

            if error != nil || isFinal {
                // Stop the audio engine if there's an error or if recognition is final
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRecording = false

                if let error = error {
                    self.errorMessage = "Speech recognition error: \(error.localizedDescription)"
                    Logger.log(self.errorMessage!, level: .error)
                }
            }
        }

        // Configure the audio engine for input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer) // Append audio to the recognition request
        }

        // Prepare and start the audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            transcribedText = "" // Clear previous text
            errorMessage = nil
            Logger.log("Speech recording started.", level: .info)
        } catch {
            errorMessage = "Audio engine could not start: \(error.localizedDescription)"
            Logger.log(errorMessage!, level: .error)
        }
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0) // Remove the tap to stop audio input
            recognitionRequest?.endAudio() // Tell the recognition request that the audio input has finished
            isRecording = false
            Logger.log("Speech recording stopped.", level: .info)
        }
        recognitionTask?.cancel() // Cancel the recognition task
        recognitionTask = nil
        recognitionRequest = nil

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            Logger.log("Failed to deactivate audio session: \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Language Configuration (Optional but Recommended)

    func setLanguage(localeIdentifier: String) {
        let newLocale = Locale(identifier: localeIdentifier)
        if SFSpeechRecognizer.supportedLocales().contains(newLocale) {
            self.currentLocale = newLocale
            // إعادة تهيئة speechRecognizer باللغة الجديدة
            speechRecognizer = SFSpeechRecognizer(locale: self.currentLocale) // هذا السطر أصبح يعمل الآن
            speechRecognizer?.delegate = self
            Logger.log("Speech recognition language set to: \(localeIdentifier)", level: .info)
        } else {
            errorMessage = "Language '\(localeIdentifier)' is not supported for speech recognition."
            Logger.log(errorMessage!, level: .warning)
        }
    }

    // MARK: - Cleanup (Important for deallocation)

    deinit {
        stopRecording() // Ensure recording is stopped and resources are released
        Logger.log("SpeechManager deinitialized.", level: .info)
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechManager: SFSpeechRecognizerDelegate {
    // This delegate method is called when the availability of the speech recognizer changes.
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            Logger.log("Speech recognizer is available.", level: .info)
            errorMessage = nil // Clear error if it becomes available
        } else {
            errorMessage = "Speech recognition not currently available. Check internet connection or device settings."
            Logger.log(errorMessage!, level: .warning)
        }
    }
}
