// Noota/Views/ChatBubbleView.swift
import SwiftUI
import AVFoundation

struct ChatBubbleView: View {
    let message: ChatDisplayMessage
    let currentUserUID: String
    @ObservedObject var textToSpeechService: TextToSpeechService
    @State private var showTranslation = false
    @State private var isPlayingAudio = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackQueue: [(index: Int, url: String, text: String)] = []
    @State private var isProcessingQueue = false
    @State private var currentPlayingIndex = -1

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.senderID == currentUserUID {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    // رسائلي - النص الأصلي
                    Text(message.originalText)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    
                    // حالة المعالجة والترجمة
                    HStack(spacing: 8) {
                        if message.processingStatus == "processing" || message.processingStatus == "partial" {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Processing translation & audio...")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        } else if message.processingStatus == "completed" {
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else if message.processingStatus == "failed" {
                            Text("Processing failed")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        // الوقت
                        Text(formatTime(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                // رسائل الآخرين
                VStack(alignment: .leading, spacing: 8) {
                    // اسم المرسل
                    Text(message.senderName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    // النص المترجم أو الأصلي
                    if let translatedText = message.translatedText, showTranslation {
                        Text(translatedText)
                            .padding(12)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    } else {
                        Text(message.originalText)
                            .padding(12)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }
                    
                    // حالة المعالجة مع شريط تقدم الصوت
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            if message.processingStatus == "processing" {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(" Generating audio...")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            } else if message.processingStatus == "partial" {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(" \(textToSpeechService.currentChunkIndex)/\(textToSpeechService.totalChunks) chunks")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            } else if message.processingStatus == "completed" {
                                Label(" Ready to play", systemImage: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else if message.processingStatus == "failed" {
                                Text("Backend processing failed")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Spacer()
                        
                        // الوقت
                        Text(formatTime(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // زر عرض الترجمة (اختياري)
                    if message.translatedText != nil {
                        Button(action: {
                            withAnimation {
                                showTranslation.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: showTranslation ? "text.bubble.fill" : "text.bubble")
                                Text(showTranslation ? "Show Original" : "Show Translation")
                            }
                            .font(.caption2)
                            .foregroundColor(.green)
                        }
                    }
                    // 🎤 Multiple chunks with synced audio playback
                    if let chunks = message.translatedChunks, !chunks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                                HStack(spacing: 12) {
                                    // Play button for this chunk
                                    Button(action: {
                                        playChunk(index: index, chunks: chunks, audioUrls: message.audioUrls ?? [], audioBuffers: message.audioBuffers ?? [])
                                    }) {
                                        Image(systemName: message.currentChunkPlaying == index ? "stop.circle.fill" : "play.circle")
                                            .font(.system(size: 16))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    // Chunk text
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(chunk)
                                            .font(.caption)
                                            .lineLimit(2)
                                        
                                        if message.currentChunkPlaying == index {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    // Fallback for single audio
                    else if let audioData = message.audioBuffer, !audioData.isEmpty {
                        Button(action: {
                            playAudio(audioData)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isPlayingAudio ? "stop.circle.fill" : "play.circle.fill")
                                Text(isPlayingAudio ? "Playing..." : "Play Audio")
                            }
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear {
            //  Auto-play audio when message appears (for received messages)
            if message.senderID != currentUserUID {
                autoPlayReceivedMessage()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    //  Auto-play received message audio chunks in sequence
    private func autoPlayReceivedMessage() {
        guard let chunks = message.translatedChunks, !chunks.isEmpty else { return }
        
        print("🎬 [iOS] Auto-playing received message with \(chunks.count) chunks")
        
        // بدء التشغيل فوراً بدون تأخير
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playChunkSequentially(startIndex: 0, chunks: chunks, audioUrls: message.audioUrls ?? [], audioBuffers: message.audioBuffers ?? [])
        }
    }
    
    //  Play chunks one after another with prefetching
    private func playChunkSequentially(startIndex: Int, chunks: [String], audioUrls: [String], audioBuffers: [Data]) {
        guard startIndex < chunks.count else {
            print(" [iOS] Finished playing all chunks")
            DispatchQueue.main.async {
                self.isPlayingAudio = false
            }
            return
        }
        
        guard startIndex < audioUrls.count, !audioUrls[startIndex].isEmpty else {
            print(" [iOS] Skipping chunk \(startIndex + 1) (no audio), moving to next...")
            playChunkSequentially(startIndex: startIndex + 1, chunks: chunks, audioUrls: audioUrls, audioBuffers: audioBuffers)
            return
        }
        
        DispatchQueue.main.async {
            self.isPlayingAudio = true
            self.currentPlayingIndex = startIndex
        }
        
        let audioUrl = audioUrls[startIndex]
        let chunkText = chunks[startIndex]
        
        print(" [iOS] Auto-playing chunk \(startIndex + 1)/\(chunks.count): \"\(chunkText)\"")
        
        // Download current chunk
        DispatchQueue.global(qos: .userInitiated).async {
            if let url = URL(string: audioUrl),
               let audioData = try? Data(contentsOf: url) {
                
                DispatchQueue.main.async {
                    do {
                        self.audioPlayer = try AVAudioPlayer(data: audioData, fileTypeHint: AVFileType.wav.rawValue)
                        
                        // Set delegate to handle when this chunk finishes
                        let nextIndex = startIndex + 1
                        self.audioPlayer?.delegate = AudioPlayerDelegate(onFinish: {
                            print("✓ Chunk \(startIndex + 1) finished, moving to chunk \(nextIndex + 1)...")
                            self.playChunkSequentially(
                                startIndex: nextIndex,
                                chunks: chunks,
                                audioUrls: audioUrls,
                                audioBuffers: audioBuffers
                            )
                        })
                        
                        self.audioPlayer?.volume = 1.0
                        self.audioPlayer?.play()
                        
                        // Prefetch next chunk while playing current one
                        if nextIndex < audioUrls.count, !audioUrls[nextIndex].isEmpty {
                            DispatchQueue.global(qos: .background).async {
                                _ = try? Data(contentsOf: URL(string: audioUrls[nextIndex])!)
                            }
                        }
                    } catch {
                        print(" Error creating AVAudioPlayer for auto-play: \(error)")
                        self.playChunkSequentially(startIndex: startIndex + 1, chunks: chunks, audioUrls: audioUrls, audioBuffers: audioBuffers)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    print(" Failed to download audio for chunk \(startIndex + 1), skipping...")
                    self.playChunkSequentially(startIndex: startIndex + 1, chunks: chunks, audioUrls: audioUrls, audioBuffers: audioBuffers)
                }
            }
        }
    }
    
    private func playAudio(_ audioData: Data) {
        do {
            DispatchQueue.main.async {
                self.isPlayingAudio = true
            }
            
            audioPlayer = try AVAudioPlayer(data: audioData, fileTypeHint: AVFileType.wav.rawValue)
            audioPlayer?.delegate = AudioPlayerDelegate(onFinish: {
                DispatchQueue.main.async {
                    self.isPlayingAudio = false
                }
            })
            audioPlayer?.play()
        } catch {
            print("Error playing audio: \(error)")
            DispatchQueue.main.async {
                self.isPlayingAudio = false
            }
        }
    }
    
    //  Play individual chunk with auto-advance
    private func playChunk(index: Int, chunks: [String], audioUrls: [String], audioBuffers: [Data]) {
        guard index < audioUrls.count, !audioUrls[index].isEmpty else { return }
        
        DispatchQueue.main.async {
            self.isPlayingAudio = true
            self.currentPlayingIndex = index
        }
        
        let audioUrl = audioUrls[index]
        let chunkText = chunks[index]
        
        print(" [iOS] Now playing chunk \(index + 1)/\(chunks.count): \"\(chunkText)\"")
        
        // Download audio from URL
        DispatchQueue.global().async {
            guard let url = URL(string: audioUrl),
                  let audioData = try? Data(contentsOf: url) else {
                DispatchQueue.main.async {
                    print("[iOS] Failed to download audio from: \(audioUrl)")
                    self.isPlayingAudio = false
                    // Continue to next chunk
                    if index + 1 < chunks.count {
                        self.playChunk(index: index + 1, chunks: chunks, audioUrls: audioUrls, audioBuffers: audioBuffers)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    self.audioPlayer = try AVAudioPlayer(data: audioData, fileTypeHint: AVFileType.wav.rawValue)
                    self.audioPlayer?.delegate = AudioPlayerDelegate(onFinish: {
                        DispatchQueue.main.async {
                            print(" [iOS] Finished playing chunk \(index + 1): \"\(chunkText)\"")
                            // Auto-advance to next chunk
                            if index + 1 < chunks.count {
                                print(" [iOS] Auto-advancing to next chunk...")
                                self.playChunk(index: index + 1, chunks: chunks, audioUrls: audioUrls, audioBuffers: audioBuffers)
                            } else {
                                // All chunks done
                                print("🏁 [iOS] All chunks finished playing")
                                self.isPlayingAudio = false
                            }
                        }
                    })
                    self.audioPlayer?.volume = 1.0
                    self.audioPlayer?.play()
                    print(" [iOS] Playing: \(chunkText)")
                } catch {
                    print("[iOS] Error creating AVAudioPlayer: \(error)")
                    self.isPlayingAudio = false
                }
            }
        }
    }
}

// Helper class for audio player delegate
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
