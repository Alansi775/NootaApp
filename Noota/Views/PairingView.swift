import SwiftUI
import Combine

struct PairingView: View {
    @EnvironmentObject var appRootManager: AppRootManager
    @ObservedObject var viewModel: PairingViewModel

    @EnvironmentObject var speechManager: SpeechManager
    @EnvironmentObject var translationService: TranslationService
    @EnvironmentObject var textToSpeechService: TextToSpeechService

    @State private var showingQRScanner = false
    @State private var showingScannerErrorAlert = false
    @State private var scannerErrorMessage: String = ""

    private var coordinator: Coordinator {
        Coordinator(parent: self)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                Text("Join or Create a Room")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 30)

                Button(action: {
                    Task {
                        await viewModel.createNewRoom()
                    }
                }) {
                    Label("Create New Room", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .padding(.horizontal)
                .disabled(viewModel.isLoading)

                if viewModel.isLoading && viewModel.roomID.isEmpty {
                    ProgressView("Creating Room...")
                        .padding()
                } else if !viewModel.roomID.isEmpty && viewModel.currentRoom?.status == .pending {
                    VStack {
                        Text("Room ID: \(viewModel.roomID)")
                            .font(.title2)
                            .padding(.top, 10)
                        
                        if let qrImage = viewModel.qrCodeImage {
                            Image(uiImage: qrImage)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .padding()
                        }
                        Text("Waiting for opponent...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Divider()
                    .padding(.vertical, 20)

                TextField("Enter Room ID", text: $viewModel.roomID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .keyboardType(.default)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Button(action: {
                    Task {
                        await viewModel.joinRoom(with: viewModel.roomID)
                    }
                }) {
                    Label("Join Room with ID", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .padding(.horizontal)
                .disabled(viewModel.roomID.isEmpty || viewModel.isLoading)

                Button(action: {
                    showingQRScanner = true
                }) {
                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .padding(.horizontal)
                .disabled(viewModel.isLoading)
                
                Spacer()

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)

            .navigationDestination(isPresented: $viewModel.showConversationView) {
                if let room = viewModel.currentRoom,
                   let currentUser = viewModel.authService.user,
                   let opponentUser = viewModel.opponentUser {
                    
                    let conversationVM = viewModel.conversationViewModel ?? ConversationViewModel(
                        room: room,
                        currentUser: currentUser,
                        opponentUser: opponentUser,
                        firestoreService: viewModel.firestoreService,
                        authService: viewModel.authService,
                        speechManager: speechManager,
                        translationService: translationService,
                        textToSpeechService: textToSpeechService
                    )
                    
                    ConversationView(viewModel: conversationVM)
                        .onAppear {
                            viewModel.conversationViewModel = conversationVM
                            Logger.log("Navigating to ConversationView for room ID: \(room.id ?? "N/A").", level: .info)
                        }
                        .onDisappear {
                            Logger.log("ConversationView did disappear. Resetting pairing view state.", level: .info)
                            viewModel.resetPairingState()
                            viewModel.conversationViewModel = nil
                        }

                } else {
                    Text("Error: Required data for conversation is missing.")
                        .foregroundColor(.red)
                        .onAppear {
                            Logger.log("Error: Conversation data missing when trying to navigate.", level: .error)
                        }
                }
            }
            
            .sheet(isPresented: $showingQRScanner) {
                QRCodeScannerView(delegate: coordinator)
            }
            .alert("Scanner Error", isPresented: $showingScannerErrorAlert) {
                Button("OK") { }
            } message: {
                Text(scannerErrorMessage)
            }
        }
    }

    class Coordinator: NSObject, QRCodeScannerDelegate {
        var parent: PairingView

        init(parent: PairingView) {
            self.parent = parent
        }

        func didScanQRCode(result: String) {
            parent.showingQRScanner = false
            parent.viewModel.roomID = result
            Logger.log("QR Code scanned: \(result). Attempting to join room.", level: .info)
            Task { @MainActor in
                await parent.viewModel.joinRoom(with: result)
            }
        }

        func scannerDidFail(error: Error) {
            parent.showingQRScanner = false
            parent.scannerErrorMessage = error.localizedDescription
            parent.showingScannerErrorAlert = true
            Logger.log("QR Scanner failed: \(error.localizedDescription)", level: .error)
            parent.viewModel.errorMessage = "QR Scanner Failed: \(error.localizedDescription)"
        }

        func scannerDidCancel() {
            parent.showingQRScanner = false
            Logger.log("QR Scanner cancelled.", level: .info)
        }
    }
}

struct PairingView_Previews: PreviewProvider {
    static var previews: some View {
        let mockAuthService = AuthService()
        let mockFirestoreService = FirestoreService()
        
        //  1. إنشاء كائن Mock من GeminiService
        let mockGeminiService = GeminiService()
        
        //  2. إنشاء كائن TranslationService وتمرير الـ Mock إليه
        let mockTranslationService = TranslationService(geminiService: mockGeminiService)
        
        mockAuthService.user = User(uid: "mockUid", email: "mock@example.com", username: "MockUser", preferredLanguageCode: "en-US")
        
        let mockViewModel = PairingViewModel(firestoreService: mockFirestoreService, authService: mockAuthService)

        return PairingView(viewModel: mockViewModel)
            .environmentObject(mockAuthService)
            .environmentObject(mockFirestoreService)
            .environmentObject(SpeechManager())
            
            // استبدال السطر القديم بالخدمة الجديدة
            .environmentObject(mockTranslationService)
            
            .environmentObject(TextToSpeechService())
            //  لا تنس تمرير GeminiService أيضاً لضمان توفره في البيئة
            .environmentObject(mockGeminiService)
    }
}
