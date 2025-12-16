// Noota/Services/TextToSpeechService.swift

import Foundation
import AVFoundation
import Combine

/// 🎤 خدمة تشغيل الصوت من الـ Backend
/// يوفر نظام قائمة انتظار لتشغيل قطع الصوت بشكل متتالي بدون فجوات
/// ✨ النسخة الجديدة: تشغيل الملفات الصوتية من الـ Backend فقط (بدون local TTS)
class TextToSpeechService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    
    // MARK: - Published Properties
    
    @Published var isSpeaking = false
    @Published var currentChunkIndex = 0
    @Published var totalChunks = 0
    
    // MARK: - Private Properties
    
    private var audioPlayer: AVAudioPlayer?
    private var audioQueue: [String] = []  // قائمة انتظار روابط الصوت
    private var isProcessingQueue = false
    private let queueLock = NSLock()  // حماية الوصول المتزامن
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    /// إعداد جلسة الصوت للتشغيل المتواصل
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            Logger.log("🔊 Audio session configured for continuous playback", level: .info)
        } catch {
            Logger.log("❌ Error configuring audio session: \(error.localizedDescription)", level: .error)
        }
    }
    
    // MARK: - Queue Management
    
    /// إضافة قطعة صوتية واحدة إلى قائمة الانتظار
    /// - Parameters:
    ///   - audioUrl: رابط القطعة الصوتية من Firebase Storage
    ///   - totalChunks: إجمالي عدد القطع (للتتبع)
    func enqueueAudioChunk(url audioUrl: String, totalChunks: Int = 0) {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        audioQueue.append(audioUrl)
        
        DispatchQueue.main.async {
            self.totalChunks = totalChunks > 0 ? totalChunks : self.totalChunks
            Logger.log("📝 Audio chunk enqueued (\(self.audioQueue.count) in queue)", level: .info)
        }
        
        // إذا لم يكن هناك تشغيل جاري، ابدأ معالجة القائمة
        if !isProcessingQueue {
            processQueue()
        }
    }
    
    /// إضافة عدة قطع صوتية مرة واحدة
    /// - Parameters:
    ///   - audioUrls: قائمة روابط الصوت
    ///   - totalChunks: إجمالي عدد القطع
    func enqueueAudioChunks(_ audioUrls: [String], totalChunks: Int = 0) {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        audioQueue.append(contentsOf: audioUrls)
        
        DispatchQueue.main.async {
            self.totalChunks = totalChunks > 0 ? totalChunks : self.totalChunks
            Logger.log("📝 \(audioUrls.count) audio chunks enqueued (\(self.audioQueue.count) total in queue)", level: .info)
        }
        
        // إذا لم يكن هناك تشغيل جاري، ابدأ معالجة القائمة
        if !isProcessingQueue {
            processQueue()
        }
    }
    
    // MARK: - Queue Processing
    
    /// معالجة قائمة الانتظار: تشغيل القطع الواحدة تلو الأخرى
    private func processQueue() {
        queueLock.lock()
        let nextUrl = audioQueue.first.map { $0 }
        queueLock.unlock()
        
        guard let urlString = nextUrl else {
            // انتهينا من القائمة
            DispatchQueue.main.async { [weak self] in
                self?.isSpeaking = false
                self?.isProcessingQueue = false
                Logger.log("✅ Audio queue completed", level: .info)
            }
            return
        }
        
        isProcessingQueue = true
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = true
        }
        
        // تشغيل التنزيل والتشغيل في background thread لتجنب blocking Main Thread
        Task(priority: .userInitiated) {
            await downloadAndPlayAudio(from: urlString)
        }
    }
    
    // MARK: - Audio Download & Playback
    
    /// تنزيل وتشغيل قطعة صوتية من Firebase Storage
    /// - Parameter urlString: رابط الملف الصوتي
    private func downloadAndPlayAudio(from urlString: String) async {
        Logger.log("⬇️ Downloading audio chunk: \(urlString.prefix(60))...", level: .info)
        
        do {
            guard let audioURL = URL(string: urlString) else {
                Logger.log("❌ Invalid audio URL", level: .error)
                removeFirstQueueItem()
                return
            }
            
            // تنزيل الملف الصوتي مع timeout
            var request = URLRequest(url: audioURL)
            request.timeoutInterval = 30.0
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // التحقق من رمز الحالة HTTP
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    Logger.log("❌ HTTP Error: \(httpResponse.statusCode)", level: .error)
                    removeFirstQueueItem()
                    return
                }
            }
            
            Logger.log("✅ Audio downloaded (\(data.count) bytes)", level: .info)
            
            // تشغيل الصوت على الـ Main Thread
            DispatchQueue.main.async { [weak self] in
                self?.playAudioData(data)
            }
            
        } catch {
            Logger.log("❌ Error downloading audio: \(error.localizedDescription)", level: .error)
            removeFirstQueueItem()
        }
    }
    
    /// تشغيل بيانات الصوت مباشرة
    /// - Parameter audioData: بيانات الملف الصوتي (WAV/MP3)
    private func playAudioData(_ audioData: Data) {
        do {
            // إيقاف التشغيل السابق
            audioPlayer?.stop()
            
            // إنشاء مشغل صوتي جديد
            audioPlayer = try AVAudioPlayer(data: audioData, fileTypeHint: AVFileType.wav.rawValue)
            audioPlayer?.delegate = self
            
            // تحديث العداد - نتأكد أنه على Main Thread
            self.currentChunkIndex += 1
            
            // بدء التشغيل
            audioPlayer?.play()
            Logger.log("▶️ Playing audio chunk (\(currentChunkIndex)/\(totalChunks))", level: .info)
            
        } catch {
            Logger.log("❌ Error creating audio player: \(error.localizedDescription)", level: .error)
            removeFirstQueueItem()
        }
    }
    
    /// إزالة أول عنصر من قائمة الانتظار والمتابعة
    private func removeFirstQueueItem() {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        if !audioQueue.isEmpty {
            audioQueue.removeFirst()
        }
        
        // استمر إلى القطعة التالية - بدون تأخير زائد
        processQueue()
    }
    
    // MARK: - Playback Control
    
    /// إيقاف التشغيل وتفريغ قائمة الانتظار
    func stopSpeaking() {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        audioPlayer?.stop()
        audioQueue.removeAll()
        isProcessingQueue = false
        
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentChunkIndex = 0
            Logger.log("⏹️ Stopped audio playback and cleared queue", level: .info)
        }
    }
    
    /// إيقاف مؤقت (لاستئناف لاحقاً)
    func pauseSpeaking() {
        audioPlayer?.pause()
        DispatchQueue.main.async {
            self.isSpeaking = false
            Logger.log("⏸️ Paused audio playback", level: .info)
        }
    }
    
    /// استئناف التشغيل
    func resumeSpeaking() {
        audioPlayer?.play()
        DispatchQueue.main.async {
            self.isSpeaking = true
            Logger.log("▶️ Resumed audio playback", level: .info)
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    /// عند انتهاء تشغيل قطعة صوتية، انتقل للقطعة التالية
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Logger.log("✅ Audio chunk playback finished (success: \(flag))", level: .info)
        removeFirstQueueItem()
    }
    
    /// في حالة حدوث خطأ أثناء التشغيل، انتقل للقطعة التالية
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Logger.log("❌ Audio decode error: \(error?.localizedDescription ?? "Unknown")", level: .error)
        removeFirstQueueItem()
    }
}
