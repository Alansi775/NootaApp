import Foundation
import Speech
import Combine
import SwiftUI

class SpeechManager: ObservableObject {
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var liveRecognizedText = ""
    @Published var error: Error?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    //  نظام التسجيل المستمر
    private var isContinuousMode = false
    private var currentLanguageCode = "en-US"
    
    //  نظام إدارة الجمل الاحترافي - تتبع آخر نص أرسلناه
    private var sentenceBuffer = ""
    private var lastSentIndex = 0 // آخر موضع أرسلناه
    private var processingTimer: Timer?
    private let sentenceCompletionDelay: TimeInterval = 1.0
    
    //  Subject لإرسال الجمل المكتملة
    private let completedSentenceSubject = PassthroughSubject<String, Never>()
    var completedSentencePublisher: AnyPublisher<String, Never> {
        completedSentenceSubject.eraseToAnyPublisher()
    }
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    Logger.log("Speech recognition authorization granted.", level: .info)
                case .denied, .restricted, .notDetermined:
                    self.error = NSError(domain: "SpeechManagerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition authorization denied."])
                    Logger.log("Speech recognition authorization failed.", level: .error)
                @unknown default:
                    self.error = NSError(domain: "SpeechManagerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown authorization status."])
                    Logger.log("Unknown speech recognition authorization status.", level: .error)
                }
            }
        }
    }
    
    //  بدء التسجيل المستمر (ضغطة واحدة فقط)
    func startContinuousRecording(languageCode: String) {
        //  إذا كان التسجيل المستمر نشطاً، تجاهل الطلب
        guard !isContinuousMode else {
            Logger.log("⏸️ Continuous recording already active. Ignoring request.", level: .info)
            return
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            requestAuthorization()
            return
        }
        
        do {
            isContinuousMode = true
            currentLanguageCode = languageCode
            resetState()
            
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            startRecognitionSession()
            
            Logger.log(" Continuous speech recording started for language: \(languageCode).", level: .info)
            
        } catch {
            self.error = error
            isContinuousMode = false
            Logger.log("Failed to start continuous recording: \(error.localizedDescription)", level: .error)
        }
    }
    
    //  بدء جلسة التعرف على الكلام
    private func startRecognitionSession() {
        guard isContinuousMode else { return }
        
        Logger.log("Starting new recognition session...", level: .debug)
        
        //  إيقاف الجلسة السابقة إذا كانت موجودة
        stopCurrentRecognitionSession()
        
        do {
            isRecording = true
            
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguageCode))
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            recognitionRequest?.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, when in
                self?.recognitionRequest?.append(buffer)
            }
            
            if !audioEngine.isRunning {
                audioEngine.prepare()
                try audioEngine.start()
            }
            
            recognitionTask = recognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.handleContinuousRecognitionResult(result: result, error: error)
                }
            }
            
            Logger.log(" Recognition session started successfully", level: .debug)
            
        } catch {
            self.error = error
            Logger.log("Failed to start recognition session: \(error.localizedDescription)", level: .error)
            
            //  إعادة المحاولة بعد ثانيتين
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.isContinuousMode {
                    self.stopCurrentRecognitionSession()
                    self.startRecognitionSession()
                }
            }
        }
    }
    
    //  معالجة نتائج التعرف المستمر
    private func handleContinuousRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result = result {
            let newText = result.bestTranscription.formattedString
            self.liveRecognizedText = newText
            
            //  معالجة النص الجديد
            if !newText.isEmpty {
                processPendingText(newText)
            }
            
            //  إذا كانت النتيجة نهائية، أعد بدء الجلسة فوراً
            if result.isFinal {
                Logger.log(" Result is final, restarting session for next sentence...", level: .debug)
                if isContinuousMode {
                    //  امسح البافر قبل البدء الجديد
                    sentenceBuffer = ""
                    liveRecognizedText = ""
                    
                    //  بدون تأخير - restart فوري
                    stopCurrentRecognitionSession()
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, self.isContinuousMode else { return }
                        self.startRecognitionSession()
                    }
                }
            }
        }
        
        //  في حالة الخطأ، أعد بدء الجلسة
        if let recognitionError = error {
            Logger.log(" Recognition error: \(recognitionError.localizedDescription)", level: .warning)
            if isContinuousMode {
                //  امسح البافر عند الخطأ أيضاً
                sentenceBuffer = ""
                liveRecognizedText = ""
                
                //  تأخير صغير قبل restart في حالة الخطأ
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.stopCurrentRecognitionSession()
                    self.startRecognitionSession()
                }
            }
        }
    }
    
    //  معالجة النص المعلق وكشف الجمل المكتملة
    private func processPendingText(_ newText: String) {
        let cleanedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return }
        
        sentenceBuffer = cleanedText
        
        //  كشف نقطة الإرسال بناءً على علامات ترقيم أو طول الجملة
        if shouldSendNow(cleanedText) {
            sendCompletedSentence()
            return
        }
        
        // إذا لم نرسل، انتظر شوية
        resetProcessingTimer()
    }
    
    //  تحديد إذا يجب إرسال الجملة الآن
    private func shouldSendNow(_ text: String) -> Bool {
        let finalPunctuation: Set<Character> = [".", "!", "?", "؟"]
        
        // علامة ترقيم واضحة = إرسل
        if let lastChar = text.last, finalPunctuation.contains(lastChar) {
            return true
        }
        
        // جملة طويلة (15+ كلمة) = احتمل انتهاء الفكرة
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        if wordCount >= 15 {
            return true
        }
        
        return false
    }
    
    
    //  إرسال الجملة المكتملة - احترافي وسلس
    private func sendCompletedSentence() {
        let cleanSentence = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSentence.isEmpty else { return }
        
        recognizedText = cleanSentence
        
        Logger.log("📤 Sending sentence: '\(cleanSentence)'", level: .info)
        
        // إعادة ضبط البافر للجملة التالية
        sentenceBuffer = ""
        liveRecognizedText = ""
        processingTimer?.invalidate()
        processingTimer = nil
        
        // إرسال الجملة عبر Publisher
        completedSentenceSubject.send(cleanSentence)
    }
    
    //  مؤقت معالجة الجمل المعلقة
    private func resetProcessingTimer() {
        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: sentenceCompletionDelay, repeats: false) { [weak self] _ in
            self?.processBufferedSentence()
        }
    }
    
    //  معالجة الجملة المحفوظة في البافر بعد الصمت
    private func processBufferedSentence() {
        guard !sentenceBuffer.isEmpty else { return }
        
        // إذا كان فيه نص في البافر = أرسله
        sendCompletedSentence()
    }

    
    //  إيقاف جلسة التعرف الحالية
    private func stopCurrentRecognitionSession() {
        Logger.log("Stopping current recognition session...", level: .debug)
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        isRecording = false
        Logger.log(" Recognition session stopped", level: .debug)
    }
    
    //  إيقاف التسجيل المستمر نهائياً
    func stopContinuousRecording() {
        guard isContinuousMode else { return }
        
        isContinuousMode = false
        processingTimer?.invalidate()
        processingTimer = nil
        
        stopCurrentRecognitionSession()
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        Logger.log("Continuous speech recording stopped.", level: .info)
    }
    
    //  إعادة ضبط الحالة
    private func resetState() {
        liveRecognizedText = ""
        recognizedText = ""
        sentenceBuffer = ""
        processingTimer?.invalidate()
        processingTimer = nil
    }
    
    //  الدوال القديمة للتوافق (لكن تعيد توجيه للنظام الجديد)
    func startRecording(languageCode: String) {
        startContinuousRecording(languageCode: languageCode)
    }
    
    func stopRecording() {
        //  في النظام المستمر، هذا لا يوقف التسجيل بل يرسل ما في البافر
        if isContinuousMode && !sentenceBuffer.isEmpty {
            processBufferedSentence()
        }
    }
    
    ///  مسح الـ buffer - بسيط وفعّال جداً
    func clearRecognitionBuffer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            Logger.log("🧹 Clearing recognition buffer...", level: .debug)
            
            //  مسح البافر فقط
            self.liveRecognizedText = ""
            self.recognizedText = ""
            self.sentenceBuffer = ""
            
            //  إيقاف مؤقت المعالجة المعلقة
            self.processingTimer?.invalidate()
            self.processingTimer = nil
            
            Logger.log(" Buffer cleared and ready for next sentence", level: .info)
        }
    }
    
    func reset() {
        stopContinuousRecording()
        resetState()
        error = nil
        Logger.log("SpeechManager state reset.", level: .info)
    }
    
    deinit {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        processingTimer?.invalidate()
        audioRecorder?.stop()
        Logger.log("SpeechManager deinitialized.", level: .info)
    }
    
    // MARK: - Audio Recording
    
    /// شروع تسجيل الصوت
    func startAudioRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "voice_\(UUID().uuidString).wav"
        recordingURL = documentsPath.appendingPathComponent(fileName)
        
        guard let recordingURL = recordingURL else {
            Logger.log("Failed to create recording URL", level: .error)
            return
        }
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ] as [String: Any]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.record()
            Logger.log(" Audio recording started: \(fileName)", level: .info)
        } catch {
            Logger.log("Failed to start audio recording: \(error.localizedDescription)", level: .error)
        }
    }
    
    /// توقف التسجيل وإرجاع مسار الملف
    func stopAudioRecording() -> URL? {
        audioRecorder?.stop()
        let url = recordingURL
        recordingURL = nil
        
        if let url = url {
            Logger.log(" Audio recording stopped: \(url.lastPathComponent)", level: .info)
        }
        
        return url
    }
}
