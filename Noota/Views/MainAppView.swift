// Noota/Views/MainAppView.swift
import SwiftUI
import Combine

struct MainAppView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var firestoreService: FirestoreService
    // 💡 أضف EnvironmentObjects للخدمات الجديدة هنا
    @EnvironmentObject var speechManager: SpeechManager // افتراضًا أنها EnvironmentObject
    @EnvironmentObject var translationService: TranslationService // افتراضًا أنها EnvironmentObject
    @EnvironmentObject var textToSpeechService: TextToSpeechService // افتراضًا أنها EnvironmentObject

    @StateObject var pairingVM: PairingViewModel

    @State private var joinRoomID: String = ""
    
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = String()
    @State private var showingQRScanner = false
    
    // ✨ تهيئة الـ Coordinator كـ State Property
    @State private var coordinator: MainAppViewCoordinator?
    
    init(authService: AuthService, firestoreService: FirestoreService) {
        _pairingVM = StateObject(wrappedValue: PairingViewModel(firestoreService: firestoreService, authService: authService))
        // لا يمكن تهيئة الـ coordinator هنا مباشرة لأن self غير متوفرة بعد
        // ستتم التهيئة في setupCoordinator()
    }
    
    // ✨ دالة لتهيئة الـ coordinator عند ظهور الـ View
    private func setupCoordinator() {
        // 💡 تأكد من التهيئة مرة واحدة فقط
        if coordinator == nil {
            coordinator = MainAppViewCoordinator(
                didScanQRCode: { scannedResult in
                    Task { @MainActor in
                        await self.pairingVM.joinRoom(with: scannedResult)
                        self.showingQRScanner = false
                    }
                },
                scannerDidFail: { error in
                    Task { @MainActor in
                        self.alertMessage = "QR Scanner Failed: \(error.localizedDescription)"
                        self.showAlert = true
                        self.showingQRScanner = false
                    }
                },
                scannerDidCancel: {
                    Task { @MainActor in
                        self.showingQRScanner = false
                    }
                }
            )
            Logger.log("MainAppViewCoordinator initialized.", level: .info)
        }
    }

    // MARK: - Sub-views (أجزاء View مستخرجة لتبسيط الـ body)

    private var welcomeSection: some View {
        VStack {
            Text("Welcome")
                .font(.system(size: 38, weight: .light, design: .default))
                .foregroundColor(.white.opacity(0.8))

            Text(authService.user?.firstName ?? authService.user?.email ?? "User")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 35)
        .padding(.horizontal, 25)
        .background(
            RoundedRectangle(cornerRadius: 35)
                .fill(Color.black.opacity(0.3))
                .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 35)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.top, 40)
        .padding(.horizontal, 20)
    }

    private var hostSessionSection: some View {
        VStack(spacing: 15) {
            Text("Host a New Session")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task {
                    await pairingVM.createNewRoom()
                }
            } label: {
                Label("Create Room", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.green, Color.teal]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }

            if let currentRoom = pairingVM.currentRoom, let roomID = currentRoom.id, !roomID.isEmpty {
                VStack(spacing: 10) {
                    Text("Your Room ID:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("**\(roomID)**")
                        .font(.title3)
                        .textSelection(.enabled)
                        .padding(8)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)

                    if let qrImage = pairingVM.qrCodeImage {
                        Image(uiImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 3)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(15)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .shadow(radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    private var joinSessionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Join an Existing Session")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack {
                TextField("Enter Room ID", text: $joinRoomID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button {
                    showingQRScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.purple.opacity(0.8))
                        .cornerRadius(10)
                        .shadow(radius: 3)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(pairingVM.isLoading)
            }
            .padding(.horizontal)

            Button {
                Task {
                    await pairingVM.joinRoom(with: joinRoomID)
                }
            } label: {
                Label("Join Room", systemImage: "person.2.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.orange, Color.red]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .shadow(radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Main Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    welcomeSection
                    hostSessionSection
                    Divider()
                        .padding(.vertical, 20)
                        .background(Color.clear)
                    joinSessionSection
                    Spacer()

                    Button("Sign Out") {
                        Task { @MainActor in
                            do {
                                try authService.signOut()
                                Logger.log("User signed out.", level: .info)
                            } catch {
                                Logger.log("Error signing out: \(error.localizedDescription)", level: .error)
                            }
                        }
                    }
                    .font(.callout)
                    .foregroundColor(.red)
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            )
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            
            .sheet(isPresented: $showingQRScanner) {
                if let coordinator = coordinator {
                    QRCodeScannerContainerView(delegate: coordinator)
                        .environmentObject(authService)
                        .environmentObject(firestoreService)
                } else {
                    Text("Error: QR Scanner initialization failed. Please restart the app.")
                        .onAppear {
                            self.alertMessage = "QR Scanner initialization error. Please restart the app."
                            self.showAlert = true
                            self.showingQRScanner = false
                        }
                }
            }
            
            .navigationDestination(isPresented: $pairingVM.showConversationView) {
                if let room = pairingVM.currentRoom,
                   let currentUser = authService.user,
                   let opponentUser = pairingVM.opponentUser {
                    
                    // ✅ إنشاء ViewModel مرة واحدة فقط
                    let conversationVM = pairingVM.conversationViewModel ?? ConversationViewModel(
                        room: room,
                        currentUser: currentUser,
                        opponentUser: opponentUser,
                        firestoreService: firestoreService,
                        authService: authService,
                        speechManager: speechManager,
                        translationService: translationService,
                        textToSpeechService: textToSpeechService
                    )
                    
                    ConversationView(viewModel: conversationVM)
                        .onAppear {
                            pairingVM.conversationViewModel = conversationVM
                        }
                        .onDisappear {
                            Logger.log("ConversationView disappeared.", level: .info)
                            pairingVM.conversationViewModel = nil
                        }
                } else {
                    Text("Error: Room data, current user, or opponent info missing. Please try again.")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .onAppear(perform: setupCoordinator)
    }
}

// MARK: - Previews

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        // ✨ تهيئة الخدمات المطلوبة للمعاينات
        let mockAuthService = AuthService()
        let mockFirestoreService = FirestoreService()
        let mockSpeechManager = SpeechManager()
        let mockTextToSpeechService = TextToSpeechService()
        
        // ✅ 1. إنشاء كائن وهمي لـ GeminiService
        let mockGeminiService = GeminiService()
        
        // ✅ 2. تهيئة TranslationService بتمرير الـ Mock Gemini Service
        let mockTranslationService = TranslationService(geminiService: mockGeminiService)
        
        // 💡 تهيئة MainAppView بالخدمات
        MainAppView(
            authService: mockAuthService,
            firestoreService: mockFirestoreService
        )
        // 💡 تمرير جميع الخدمات كـ EnvironmentObject
        .environmentObject(mockAuthService)
        .environmentObject(mockFirestoreService)
        .environmentObject(mockSpeechManager)
        
        // ❌ استبدال السطر القديم بالخدمة الجديدة
        .environmentObject(mockTranslationService)
        
        .environmentObject(mockTextToSpeechService)
        
        // ✅ لا تنس تمرير GeminiService
        .environmentObject(mockGeminiService)
    }
}
