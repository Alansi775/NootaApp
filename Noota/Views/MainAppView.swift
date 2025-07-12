// Noota/Views/MainAppView.swift
import SwiftUI
import Combine

struct MainAppView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject var pairingVM: PairingViewModel

    @State private var joinRoomID: String = ""
    
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    @State private var showingQRScanner = false
    // @State private var showRoomView: Bool = false // تم نقلها إلى PairingViewModel وهي الآن showConversationView
    // @State private var opponentName: String? // تم نقلها إلى PairingViewModel وهي الآن opponentUser

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
                        do {
                            try await self.pairingVM.joinRoom(with: scannedResult)
                            // عند النجاح، سيتم تغيير showConversationView في PairingViewModel، وسيتم التعامل مع الانتقال تلقائيا
                        } catch {
                            self.alertMessage = "Failed to join room from QR: \(error.localizedDescription)"
                            self.showAlert = true
                        }
                        self.showingQRScanner = false // إغلاق الـ sheet بعد العملية
                    }
                },
                scannerDidFail: { error in
                    Task { @MainActor in
                        self.alertMessage = "QR Scanner Failed: \(error.localizedDescription)"
                        self.showAlert = true
                        self.showingQRScanner = false // إغلاق الـ sheet
                    }
                },
                scannerDidCancel: {
                    Task { @MainActor in
                        self.showingQRScanner = false // إغلاق الـ sheet
                    }
                }
            )
            Logger.log("MainAppViewCoordinator initialized.", level: .info)
        }
    }

    var body: some View {
        // 💡 التغيير هنا: استخدام NavigationStack بدلاً من NavigationView
        // هذا ضروري لكي يعمل navigationDestination بشكل صحيح
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
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

                    // --- قسم إنشاء الغرفة ---
                    VStack(spacing: 15) {
                        Text("Host a New Session")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            Task {
                                await pairingVM.createNewRoom() // لا نحتاج try await هنا لأنها تتعامل مع أخطائها داخليًا
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

                        // عرض Room ID و QR Code إذا تم إنشاء غرفة
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

                                // عرض الـ QR Code هنا
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

                    Divider()
                        .padding(.vertical, 20)
                        .background(Color.clear)

                    // --- قسم الانضمام لغرفة موجودة ---
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Join an Existing Session")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        HStack { // 💡 وضع TextField وزر QR في HStack
                            TextField("Enter Room ID", text: $joinRoomID)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            // 💡 زر مسح QR Code داخل مربع TextField
                            Button {
                                showingQRScanner = true // يفتح الـ sheet
                            } label: {
                                Image(systemName: "qrcode.viewfinder") // أيقونة فقط
                                    .font(.title2)
                                    .foregroundColor(.white) // لون الأيقونة
                                    .padding(12) // لجعلها مربعة أكبر قليلاً
                                    .background(Color.purple.opacity(0.8)) // لون خلفية الزر
                                    .cornerRadius(10) // حواف دائرية
                                    .shadow(radius: 3)
                            }
                            .buttonStyle(PlainButtonStyle()) // لإزالة التأثيرات الافتراضية
                            .disabled(pairingVM.isLoading) // تعطيل الزر أثناء التحميل
                        }
                        .padding(.horizontal) // تطبيق padding على الـ HStack بأكمله

                        Button {
                            Task {
                                await pairingVM.joinRoom(with: joinRoomID) // لا نحتاج try await هنا لأنها تتعامل مع أخطائها داخليًا
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

                    Spacer()

                    Button("Sign Out") {
                        Task { @MainActor in // تأكد من تشغيلها على MainActor
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
            
            // --- ✨ أضف هذا الجزء الجديد هنا (الـ sheet الخاص بماسح الـ QR) ---
            .sheet(isPresented: $showingQRScanner) {
                // نستخدم هنا QRCodeScannerView الذي قمت بإنشائه،
                // ونمرر له الـ coordinator كـ delegate ليتلقى نتائج المسح
                if let coordinator = coordinator { // نتأكد أن الـ coordinator تم تهيئته
                    QRCodeScannerView(delegate: coordinator)
                        // من الجيد دائمًا تمرير EnvironmentObjects الضرورية إذا كان QRCodeScannerView يعتمد عليها
                        .environmentObject(authService)
                        .environmentObject(firestoreService)
                } else {
                    // رسالة خطأ احتياطية إذا لم يتم تهيئة الـ coordinator لسبب ما
                    Text("Error: QR Scanner initialization failed. Please restart the app.")
                        .onAppear {
                            self.alertMessage = "QR Scanner initialization error. Please restart the app."
                            self.showAlert = true
                            self.showingQRScanner = false // إغلاق الـ sheet
                        }
                }
            }
            
            // ✨ التعديل هنا: استخدام pairingVM.showConversationView
            .navigationDestination(isPresented: $pairingVM.showConversationView) {
                // نضمن أن البيانات موجودة قبل تمريرها
                if let room = pairingVM.currentRoom,
                   let currentUser = authService.user,
                   let opponentUser = pairingVM.opponentUser { // استخدام opponentUser من PairingViewModel
                    
                    // ✨ يجب أن نمرر الآن Room و CurrentUser و OpponentUser
                    ConversationView(
                        room: room,
                        currentUser: currentUser,
                        opponentUser: opponentUser, // نمرر كائن User كامل
                        pairingVM: pairingVM
                    )
                    // عندما يتم الخروج من ConversationView (بالضغط على زر الرجوع أو leave room)
                    .onDisappear {
                        // هذا سيتم التعامل معه بواسطة زر "Leave Room" داخل ConversationView
                        // أو إذا تم حذف الغرفة من طرف آخر، فإن `pairingVM.currentRoom` سيصبح `nil`
                        // وهذا سيؤدي إلى تعيين `pairingVM.showConversationView = false` تلقائيا
                        Logger.log("ConversationView disappeared.", level: .info)
                    }
                } else {
                    // Fallback view or error message if data is missing
                    Text("Error: Room data, current user, or opponent info missing. Please try again.")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .onAppear(perform: setupCoordinator) // ✨ استدعاء setupCoordinator عند ظهور الـ View
    }
}

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView(authService: AuthService(), firestoreService: FirestoreService())
            .environmentObject(AuthService())
            .environmentObject(FirestoreService())
    }
}
