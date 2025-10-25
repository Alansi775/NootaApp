// Noota/Views/ConversationView.swift

import SwiftUI
import Combine
import AVFoundation

struct ConversationView: View {
    @StateObject var viewModel: ConversationViewModel
    @EnvironmentObject var speechManager: SpeechManager
    @EnvironmentObject var translationService: TranslationService
    @EnvironmentObject var textToSpeechService: TextToSpeechService
    @Environment(\.dismiss) var dismiss

    @State private var messageOpacity: Double = 0.0

    var body: some View {
        VStack(spacing: 0) {
            // 1. Header View
            HeaderView(viewModel: viewModel, dismiss: _dismiss)

            Spacer()

            // 2. Live Speech Display
            LiveSpeechDisplayView(viewModel: viewModel)

            // 3. Translated Message Display
            TranslatedMessageDisplayView(viewModel: viewModel, messageOpacity: $messageOpacity)

            Spacer()

            VStack(spacing: 20) {
                // 4. Language Controls
                // ✨ تمرير viewModel.supportedLanguages مباشرةً بدلاً من languages
                LanguageControlsView(viewModel: viewModel) // لا حاجة لتمرير languages هنا بعد الآن

                // 5. Microphone Button
                MicrophoneButtonView(viewModel: viewModel)

                Text(viewModel.speechStatusText)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 30)
            }
            .padding(.bottom, 30)
            .padding(.top, 15)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.2))
                    .ignoresSafeArea(.container, edges: .bottom)
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: -5)
            )
            .padding(.horizontal)
            .padding(.top, -20)
        }
        .navigationBarHidden(true)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .onAppear {
            Logger.log("ConversationView appeared for room: \(viewModel.room.id ?? "N/A")", level: .info)
            Logger.log("Current user: \(viewModel.currentUser.username ?? "N/A"), Opponent: \(viewModel.opponentUser.username ?? "N/A")", level: .info)
            viewModel.onAppear()
        }
        .onDisappear {
            Logger.log("ConversationView disappeared.", level: .info)
            viewModel.onDisappear()
        }
        .onChange(of: viewModel.room.status) { newStatus in
            if newStatus == .ended || newStatus == .pending {
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        }
        .alert(item: $viewModel.errorMessage) { errorAlert in
            Alert(title: Text("خطأ"), message: Text(errorAlert.message), dismissButton: .default(Text("حسناً")))
        }
    }
}

// --- Subviews (لا تغيير هنا) ---

struct HeaderView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        HStack {
            Group {
                // نفضل استخدام firstName إن وجد، ثم username، ثم email
                if let firstName = viewModel.opponentUser.firstName, !firstName.isEmpty {
                    Text(firstName)
                } else if let username = viewModel.opponentUser.username, !username.isEmpty {
                    Text(username)
                } else if let email = viewModel.opponentUser.email {
                    Text(email.components(separatedBy: "@").first ?? "Opponent")
                } else {
                    Text("Loading...")
                }
            }
            .font(.system(size: 38, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Spacer()

            Button("Leave") {
                Task { @MainActor in
                    do {
                        try await viewModel.leaveRoom()
                        dismiss()
                    } catch {
                        Logger.log("Error leaving room: \(error.localizedDescription)", level: .error)
                        // يمكن إضافة alert للخطأ هنا
                    }
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.red.opacity(0.6))
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .padding([.horizontal, .bottom])
        .padding(.top, 40)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea(.container, edges: .top)
        )
    }
}

struct LiveSpeechDisplayView: View {
    @ObservedObject var viewModel: ConversationViewModel

    var body: some View {
        if viewModel.isRecording && !viewModel.liveRecognizedText.isEmpty {
            Text(viewModel.liveRecognizedText)
                .font(.title)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.6))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 20)
                .transition(.opacity)
                .animation(.easeIn(duration: 0.2), value: viewModel.liveRecognizedText)
        }
    }
}

struct TranslatedMessageDisplayView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @Binding var messageOpacity: Double

    var body: some View {
        if let displayMessage = viewModel.displayedMessage, !displayMessage.isEmpty, !viewModel.isRecording {
            Text(displayMessage)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding(30)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
                .opacity(messageOpacity)
                .animation(.easeIn(duration: 0.3), value: messageOpacity)
                .padding(.horizontal, 30)
                .onChange(of: displayMessage) { newMessage in
                    messageOpacity = 0.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        messageOpacity = 1.0
                    }
                }
        } else if !viewModel.isRecording && viewModel.liveRecognizedText.isEmpty && viewModel.displayedMessage == nil {
            Text("Start speaking to begin the conversation...")
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }
}

struct LanguageControlsView: View {
    @ObservedObject var viewModel: ConversationViewModel
    // ✨ إزالة let languages: [String: String] بما أننا سنستخدم viewModel.supportedLanguages
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                // ✨ التأكد من استخدام viewModel.supportedLanguages هنا
                Text("My Language: \(viewModel.supportedLanguages.first(where: { $0.value == viewModel.selectedLanguage })?.key ?? "Unknown")")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // ✨ التأكد من أن ForEach يستخدم viewModel.supportedLanguages أيضًا
                // واستخدام المفاتيح (key) كـ Text والـ قيم (value) كـ tag
                Picker("Select Language", selection: $viewModel.selectedLanguage) {
                    ForEach(viewModel.supportedLanguages.keys.sorted(), id: \.self) { key in
                        Text(key)
                            .tag(viewModel.supportedLanguages[key]!) // هنا نستخدم القيمة (الكود) كـ tag
                    }
                }
                .pickerStyle(.menu)
                .accentColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                )
                .onChange(of: viewModel.selectedLanguage) { newLang in
                    Task { @MainActor in
                        Logger.log("Picker selected language changed to: \(newLang)", level: .info)
                        await viewModel.updateMyLanguageInRoom(languageCode: newLang)
                    }
                }
            }
            .padding(.horizontal)

            HStack {
                if let oppLangCode = viewModel.opponentLanguage,
                   let oppLangName = viewModel.supportedLanguages.first(where: { $0.value == oppLangCode })?.key {
                    Text("Opponent's Language: \(oppLangName)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("Waiting for opponent to select language...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

struct MicrophoneButtonView: View {
    @ObservedObject var viewModel: ConversationViewModel

    var body: some View {
        Button {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    DispatchQueue.main.async {
                        viewModel.toggleContinuousRecording()
                    }
                } else {
                    Logger.log("Microphone access denied.", level: .warning)
                    viewModel.errorMessage = ErrorAlert(message: "Microphone access is required for speech. Please enable it in Settings.")
                }
            }
        } label: {
            Image(systemName: viewModel.isRecording ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 45))
                .padding(28)
                .background(
                    Circle()
                        .fill(viewModel.isRecording ? Color.red.opacity(0.7) : Color.green.opacity(0.7))
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                )
                .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// --- Preview Provider ---

struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        var mockCurrentUser = User(uid: "user1", email: "user1@example.com", firstName: "Alice", lastName: "Smith")
        mockCurrentUser.username = "Alice"
        mockCurrentUser.preferredLanguageCode = "en-US"

        var mockOpponentUser = User(uid: "user2", email: "user2@example.com", firstName: "Mohammed", lastName: "Sales")
        mockOpponentUser.username = "Mohammed"
        mockOpponentUser.preferredLanguageCode = "ar-SA"

        var mockRoom = Room(id: "mockRoom123", hostUserID: "user1", participantUIDs: ["user1", "user2"], status: .active)
        mockRoom.participantLanguages = ["user1": "en-US", "user2": "ar-SA"]

        let mockFirestoreService = FirestoreService()
        let mockAuthService = AuthService()
        mockAuthService.user = mockCurrentUser

        let mockSpeechManager = SpeechManager()
        
        // ✅ 1. إنشاء كائن وهمي لـ GeminiService
        let mockGeminiService = GeminiService()
        
        // ✅ 2. تهيئة TranslationService بتمرير الـ Mock Gemini Service
        let mockTranslationService = TranslationService(geminiService: mockGeminiService)
        
        let mockTextToSpeechService = TextToSpeechService()

        // ⚠️ 3. يجب تحديث تهيئة ViewModel أيضًا إذا كانت تستخدم GeminiService،
        // لكنها هنا تستخدم TranslationService و TranslationService هو الذي يستخدم Gemini.
        // لذا، التهيئة هنا صحيحة (تستخدم mockTranslationService الذي تم إنشاؤه في الخطوة 2).
        let mockVM = ConversationViewModel(
            room: mockRoom,
            currentUser: mockCurrentUser,
            opponentUser: mockOpponentUser,
            firestoreService: mockFirestoreService,
            authService: mockAuthService,
            speechManager: mockSpeechManager,
            translationService: mockTranslationService, // ✅ تستخدم النسخة الجديدة
            textToSpeechService: mockTextToSpeechService
        )

        mockVM.displayedMessage = "Hello, this is a test message!"
        mockVM.speechStatusText = "Recording..."
        mockVM.liveRecognizedText = "This is what I'm saying..."

        return ConversationView(viewModel: mockVM)
            .environmentObject(mockAuthService)
            .environmentObject(mockFirestoreService)
            .environmentObject(mockSpeechManager)
            .environmentObject(mockTranslationService)
            .environmentObject(mockTextToSpeechService)
            .environmentObject(mockGeminiService) // ✅ لا تنس تمرير GeminiService إلى البيئة
    }
}
