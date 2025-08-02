// Noota/Views/ChatBubbleView.swift
import SwiftUI

struct ChatBubbleView: View {
    let message: ChatDisplayMessage // الآن تستقبل ChatDisplayMessage
    let currentUserUID: String

    var body: some View {
        HStack {
            if message.senderID == currentUserUID {
                Spacer()
                Text(message.originalText) // رسائلي أنا تظهر بلغتي الأصلية
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.displayText) // رسائل الآخرين تظهر بالنص المترجم أو الأصلي
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(10)

                    if message.isTranslating {
                        Text("Translating...")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    } else if let error = message.translationError {
                        Text("Translation Error: \(error)")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}
