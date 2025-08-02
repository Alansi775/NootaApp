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
    
    // ✅ نظام التسجيل المستمر
    private var isContinuousMode = false
    private var lastProcessedText = ""
    private var pendingText = ""
    private var currentLanguageCode = "en-US"
    
    // ✅ نظام إدارة الجمل الذكي
    private var sentenceBuffer = ""
    private var lastSentenceTime = Date()
    private var processingTimer: Timer?
    private let sentenceCompletionDelay: TimeInterval = 1.8 // وقت انتظار لإكمال الجملة
    
    // ✅ نظام كشف الجمل
    private var wordCount = 0
    private var hasRecentActivity = false
    
    // ✅ Subject لإرسال الجمل المكتملة
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
    
    // ✅ بدء التسجيل المستمر (ضغطة واحدة فقط)
    func startContinuousRecording(languageCode: String) {
        // ✅ إذا كان التسجيل المستمر نشطاً، تجاهل الطلب
        guard !isContinuousMode else {
            Logger.log("Continuous recording already active. Ignoring request.", level: .info)
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
            
            Logger.log("Continuous speech recording started for language: \(languageCode).", level: .info)
            
        } catch {
            self.error = error
            isContinuousMode = false
            Logger.log("Failed to start continuous recording: \(error.localizedDescription)", level: .error)
        }
    }
    
    // ✅ بدء جلسة التعرف على الكلام
    private func startRecognitionSession() {
        guard isContinuousMode else { return }
        
        // ✅ إيقاف الجلسة السابقة إذا كانت موجودة
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
            
        } catch {
            self.error = error
            Logger.log("Failed to start recognition session: \(error.localizedDescription)", level: .error)
            
            // ✅ إعادة المحاولة بعد ثانيتين
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.isContinuousMode {
                    self.restartRecognitionSession()
                }
            }
        }
    }
    
    // ✅ معالجة نتائج التعرف المستمر
    private func handleContinuousRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        var shouldRestart = false
        
        if let result = result {
            let newText = result.bestTranscription.formattedString
            self.liveRecognizedText = newText
            
            // ✅ معالجة النص الجديد
            if !newText.isEmpty {
                hasRecentActivity = true
                lastSentenceTime = Date()
                processPendingText(newText)
            }
            
            // ✅ إذا كانت النتيجة نهائية، أعد بدء الجلسة
            if result.isFinal {
                shouldRestart = true
            }
        }
        
        // ✅ في حالة الخطأ، أعد بدء الجلسة
        if let recognitionError = error {
            Logger.log("Recognition error (will restart): \(recognitionError.localizedDescription)", level: .debug)
            shouldRestart = true
        }
        
        // ✅ إعادة بدء الجلسة إذا لزم الأمر
        if shouldRestart && isContinuousMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.restartRecognitionSession()
            }
        }
    }
    
    // ✅ معالجة النص المعلق وكشف الجمل المكتملة
    private func processPendingText(_ newText: String) {
        let cleanedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // ✅ تجنب معالجة نفس النص مرة أخرى
        guard cleanedText != lastProcessedText else { return }
        
        sentenceBuffer = cleanedText
        
        // ✅ إعادة ضبط مؤقت المعالجة
        resetProcessingTimer()
        
        // ✅ كشف الجمل المكتملة فوراً
        if let completedSentence = extractCompletedSentence(from: cleanedText) {
            sendCompletedSentence(completedSentence)
        }
    }
    
    // ✅ استخراج الجمل المكتملة
    private func extractCompletedSentence(from text: String) -> String? {
        let sentences = splitIntoSentences(text)
        
        // ✅ إذا كان لدينا أكثر من جملة، أرسل الجملة الأولى المكتملة
        if sentences.count > 1 {
            let firstSentence = sentences[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if isCompleteSentence(firstSentence) && firstSentence != lastProcessedText {
                return firstSentence
            }
        }
        
        // ✅ أو إذا كانت الجملة الحالية مكتملة بوضوح
        if sentences.count == 1 {
            let sentence = sentences[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if isDefinitelyCompleteSentence(sentence) && sentence != lastProcessedText {
                return sentence
            }
        }
        
        return nil
    }
    
    // ✅ تقسيم النص إلى جمل
    private func splitIntoSentences(_ text: String) -> [String] {
        let sentenceEnders: Set<Character> = [".", "!", "?", "؟", ".", "！", "？"]
        var sentences: [String] = []
        var currentSentence = ""
        
        for char in text {
            currentSentence.append(char)
            
            if sentenceEnders.contains(char) {
                sentences.append(currentSentence)
                currentSentence = ""
            }
        }
        
        if !currentSentence.isEmpty {
            sentences.append(currentSentence)
        }
        
        return sentences.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    // ✅ فحص إذا كانت الجملة مكتملة
    private func isCompleteSentence(_ sentence: String) -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalPunctuation: Set<Character> = [".", "!", "?", "؟", ".", "！", "？"]
        
        // ✅ جملة تنتهي بعلامة ترقيم نهائية
        if let lastChar = trimmed.last, finalPunctuation.contains(lastChar) {
            return trimmed.count > 5 // على الأقل 5 أحرف
        }
        
        return false
    }
    
    // ✅ فحص إذا كانت الجملة مكتملة بوضوح (حتى بدون علامات ترقيم)
    private func isDefinitelyCompleteSentence(_ sentence: String) -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        // ✅ جملة طويلة بما فيه الكفاية (أكثر من 8 كلمات)
        if words.count > 8 {
            return true
        }
        
        // ✅ تحتوي على تعبيرات كاملة
        let completeExpressions = ["السلام عليكم", "كيف الحال", "ان شاء الله", "الحمد لله", "بارك الله فيك"]
        for expression in completeExpressions {
            if trimmed.lowercased().contains(expression.lowercased()) && words.count >= 3 {
                return true
            }
        }
        
        return false
    }
    
    // ✅ إرسال الجملة المكتملة
    private func sendCompletedSentence(_ sentence: String) {
        let cleanSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanSentence.isEmpty && cleanSentence != lastProcessedText else { return }
        
        lastProcessedText = cleanSentence
        recognizedText = cleanSentence
        
        Logger.log("Completed sentence detected: '\(cleanSentence)'", level: .info)
        
        // ✅ إرسال الجملة عبر الـ Publisher
        completedSentenceSubject.send(cleanSentence)
        
        // ✅ إعادة ضبط البافر
        sentenceBuffer = ""
        liveRecognizedText = ""
    }
    
    // ✅ مؤقت معالجة الجمل المعلقة
    private func resetProcessingTimer() {
        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: sentenceCompletionDelay, repeats: false) { [weak self] _ in
            self?.processBufferedSentence()
        }
    }
    
    // ✅ معالجة الجملة المحفوظة في البافر
    private func processBufferedSentence() {
        guard !sentenceBuffer.isEmpty else { return }
        
        let timeSinceLastActivity = Date().timeIntervalSince(lastSentenceTime)
        
        // ✅ إذا مر وقت كافٍ من الصمت وهناك محتوى جيد
        if timeSinceLastActivity >= sentenceCompletionDelay {
            let cleanBuffer = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            let words = cleanBuffer.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            
            // ✅ إرسال الجملة إذا كانت تحتوي على محتوى كافٍ
            if words.count >= 3 && cleanBuffer != lastProcessedText {
                sendCompletedSentence(cleanBuffer)
            }
        }
    }
    
    // ✅ إعادة بدء جلسة التعرف
    private func restartRecognitionSession() {
        guard isContinuousMode else { return }
        
        Logger.log("Restarting recognition session...", level: .debug)
        
        stopCurrentRecognitionSession()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard self.isContinuousMode else { return }
            self.startRecognitionSession()
        }
    }
    
    // ✅ إيقاف جلسة التعرف الحالية
    private func stopCurrentRecognitionSession() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        isRecording = false
    }
    
    // ✅ إيقاف التسجيل المستمر نهائياً
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
    
    // ✅ إعادة ضبط الحالة
    private func resetState() {
        liveRecognizedText = ""
        recognizedText = ""
        lastProcessedText = ""
        sentenceBuffer = ""
        wordCount = 0
        hasRecentActivity = false
        lastSentenceTime = Date()
        processingTimer?.invalidate()
        processingTimer = nil
    }
    
    // ✅ الدوال القديمة للتوافق (لكن تعيد توجيه للنظام الجديد)
    func startRecording(languageCode: String) {
        startContinuousRecording(languageCode: languageCode)
    }
    
    func stopRecording() {
        // ✅ في النظام المستمر، هذا لا يوقف التسجيل بل يرسل ما في البافر
        if isContinuousMode && !sentenceBuffer.isEmpty {
            processBufferedSentence()
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
        Logger.log("SpeechManager deinitialized.", level: .info)
    }
}
