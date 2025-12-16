// Noota/Views/ChatBubbleView.swift
import SwiftUI

struct ChatBubbleView: View {
    let message: ChatDisplayMessage
    let currentUserUID: String
    @ObservedObject var textToSpeechService: TextToSpeechService
    @State private var showTranslation = false

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
                            Text("❌ Processing failed")
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
                                    Text("🎙️ Generating audio...")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            } else if message.processingStatus == "partial" {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("📝 \(textToSpeechService.currentChunkIndex)/\(textToSpeechService.totalChunks) chunks")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            } else if message.processingStatus == "completed" {
                                Label("✅ Ready to play", systemImage: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else if message.processingStatus == "failed" {
                                Text("❌ Backend processing failed")
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
                }
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
