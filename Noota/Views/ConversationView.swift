// Noota/Views/ConversationView.swift
import SwiftUI
import Combine
import AVFoundation

struct ConversationView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @Environment(\.presentationMode) var presentationMode

    let languages = [
        "English": "en-US",
        "العربية": "ar-SA",
        "Türkçe": "tr-TR"
    ]
    
    @State private var showingLanguagePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // شريط العنوان المخصص - تصميم مشابه لـ MainAppView
            HStack {
                // اسم المستخدم الآخر
                Text(viewModel.opponentUser.firstName ?? viewModel.opponentUser.email ?? "Opponent")
                    .font(.system(size: 38, weight: .bold, design: .rounded)) // حجم ووزن خط أكبر
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
                
                // زر "Leave" - بتصميم أنيق
                Button("Leave") {
                    Task { @MainActor in
                        await viewModel.leaveRoom()
                    }
                }
                .font(.headline)
                .foregroundColor(.white) // لون نص أبيض ليتناسب مع الخلفية
                .padding(.horizontal, 20) // مساحة أكبر
                .padding(.vertical, 10) // مساحة أكبر
                .background(
                    RoundedRectangle(cornerRadius: 15) // حواف دائرية أكثر
                        .fill(Color.red.opacity(0.6)) // لون أحمر مع شفافية
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3) // ظل خفيف
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1) // حدود بيضاء شفافة
                )
            }
            .padding([.horizontal, .bottom]) // padding أفقي وسفلي
            .padding(.top, 40) // padding علوي أكبر لشريط الحالة
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea(.container, edges: .top) // خلفية متدرجة شفافة
            )

            // عرض الرسائل هنا - الخلفية الرئيسية لمنطقة المحادثة
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(spacing: 12) { // مسافة بين الفقاعات
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message, isCurrentUser: message.senderUID == viewModel.currentUser.uid)
                                .id(message.id) // لإمكانية التمرير إلى الرسالة الأخيرة
                        }
                    }
                    .padding()
                    .onChange(of: viewModel.messages.count) { _ in
                        // التمرير التلقائي إلى الرسالة الأخيرة عند إضافة رسالة جديدة
                        if let lastMessage = viewModel.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color.black.opacity(0.05).ignoresSafeArea()) // خلفية فاتحة جدًا
            .cornerRadius(20) // حواف دائرية للجزء العلوي من منطقة المحادثة
            .padding(.horizontal) // padding أفقي لمنطقة المحادثة ككل
            .padding(.top, -20) // لسحبها لأعلى قليلاً وتداخلها مع الشريط العلوي

            // قسم اختيار اللغة والتحكم في المايكروفون - تصميم مشابه لـ MainAppView
            VStack(spacing: 20) { // زيادة المسافة بين العناصر
                // اختيار اللغة
                HStack {
                    Text("My Language:")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer() // يدفع الـ Picker إلى اليمين
                    
                    Picker("Select Language", selection: $viewModel.selectedLanguage) {
                        ForEach(languages.keys.sorted(), id: \.self) { key in
                            Text(key).tag(languages[key]!)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1)) // خلفية خفيفة للـ Picker
                    )
                    .onChange(of: viewModel.selectedLanguage) { newLang in
                        Task { @MainActor in
                            await viewModel.updateMyLanguageInRoom(languageCode: newLang)
                        }
                    }
                }
                .padding(.horizontal)

                // معلومات لغة الخصم
                if let oppLangCode = viewModel.opponentLanguage,
                   let oppLangName = languages.first(where: { $0.value == oppLangCode })?.key {
                    Text("Opponent's Language: \(oppLangName)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("Waiting for opponent to select language...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // زر المايكروفون - تصميم أنيق
                Button {
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        if granted {
                            DispatchQueue.main.async {
                                if viewModel.isRecording {
                                    viewModel.stopRecording()
                                } else {
                                    viewModel.startRecording()
                                }
                            }
                        } else {
                            Logger.log("Microphone access denied.", level: .warning)
                        }
                    }
                } label: {
                    Image(systemName: viewModel.isRecording ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 45)) // أيقونة أكبر
                        .padding(28) // مساحة داخلية أكبر
                        .background(
                            Circle()
                                .fill(viewModel.isRecording ? Color.red.opacity(0.7) : Color.green.opacity(0.7)) // ألوان شفافة
                                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5) // ظل واضح
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())

                // عرض النص المسجل أو المترجم
                Text(viewModel.recordedText.isEmpty ? (viewModel.translatedText.isEmpty ? "Start speaking..." : viewModel.translatedText) : viewModel.recordedText)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9)) // نص أكثر وضوحًا
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 30) // حد أدنى للارتفاع حتى لا يختفي النص
            }
            .padding(.bottom, 30) // padding سفلي أكبر
            .padding(.top, 15) // padding علوي
            .background(
                RoundedRectangle(cornerRadius: 20) // حواف دائرية للجزء العلوي
                    .fill(Color.black.opacity(0.2)) // خلفية شفافة وداكنة قليلاً
                    .ignoresSafeArea(.container, edges: .bottom)
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: -5) // ظل علوي
            )
            .padding(.horizontal) // padding أفقي للعنصر بالكامل
            .padding(.top, -20) // لسحبه لأعلى قليلاً وتداخله مع منطقة الرسائل
        }
        .navigationBarHidden(true)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea() // خلفية عامة متناسقة
        )
        .onAppear {
            Logger.log("ConversationView appeared for room: \(viewModel.currentRoom.id ?? "N/A")", level: .info)
            Logger.log("Current user: \(viewModel.currentUser.firstName ?? "N/A"), Opponent: \(viewModel.opponentUser.firstName ?? "N/A")", level: .info)
        }
        .onChange(of: viewModel.currentRoom.status) { newStatus in
            if newStatus == .ended || newStatus == .pending {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// مكون فقاعة الرسالة (MessageBubble)
struct MessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading) {
                // النص الأصلي (للمتحدث)
                Text(message.text)
                    .font(.body)
                    .padding(10) // padding أكبر
                    .background(isCurrentUser ? Color.blue.opacity(0.8) : Color.gray.opacity(0.8)) // ألوان أغمق قليلاً
                    .cornerRadius(15) // حواف أكثر دائرية
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2) // ظل خفيف

                // النص المترجم (للمستمع)
                if let translatedText = message.translatedText, !translatedText.isEmpty && !isCurrentUser {
                    Text(translatedText)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                        .foregroundColor(.white.opacity(0.8)) // نص أكثر وضوحًا
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isCurrentUser ? .trailing : .leading)

            if !isCurrentUser {
                Spacer()
            }
        }
    }
}

// معاينة ConversationView
struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        let mockCurrentUser = User(uid: "user1", email: "user1@example.com", firstName: "Alice", lastName: nil)
        let mockOpponentUser = User(uid: "user2", email: "user2@example.com", firstName: "Bob", lastName: nil)
        
        var mockRoom = Room(id: "mockRoom123", hostUserID: "user1", participantUIDs: ["user1", "user2"], status: .active)
        mockRoom.participantLanguages = ["user1": "en-US", "user2": "ar-SA"]
        
        let mockFirestoreService = FirestoreService()
        let mockAuthService = AuthService()
        
        let mockVM = ConversationViewModel(room: mockRoom, currentUser: mockCurrentUser, opponentUser: mockOpponentUser, firestoreService: mockFirestoreService)
        
        // إضافة بعض الرسائل الوهمية للمعاين
        mockVM.messages.append(ChatMessage(id: UUID().uuidString, senderUID: "user1", text: "Hello, how are you?", translatedText: "مرحبا، كيف حالك؟", timestamp: Date()))
        mockVM.messages.append(ChatMessage(id: UUID().uuidString, senderUID: "user2", text: "أنا بخير، ماذا عنك؟", translatedText: "I'm fine, how about you?", timestamp: Date().addingTimeInterval(1)))
        
        return ConversationView(viewModel: mockVM)
            .environmentObject(mockAuthService)
            .environmentObject(mockFirestoreService)
    }
}
