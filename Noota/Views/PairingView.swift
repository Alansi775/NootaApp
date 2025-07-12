// Noota/Views/PairingView.swift
import SwiftUI

struct PairingView: View {
    @EnvironmentObject var appRootManager: AppRootManager // للتنقل
    @ObservedObject var viewModel: PairingViewModel

    @State private var showingQRScanner = false
    @State private var scannedRoomID: String?

    var body: some View {
        NavigationView { // تأكد من وجود NavigationView للتنقل
            VStack(spacing: 20) {
                Spacer()

                Text("Join or Create a Room")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 30)

                // قسم إنشاء غرفة
                Button(action: {
                  //  viewModel.createNewRoom()
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
                .disabled(viewModel.isLoading) // تعطيل الزر أثناء التحميل

                if viewModel.isLoading && viewModel.roomID.isEmpty {
                    ProgressView("Creating Room...")
                        .padding()
                } else if !viewModel.roomID.isEmpty {
                    VStack {
                        Text("Room ID: \(viewModel.roomID)")
                            .font(.title2)
                            .padding(.top, 10)
                        
                        if let qrImage = viewModel.qrCodeImage {
                            Image(uiImage: qrImage)
                                .resizable()
                                .interpolation(.none) // لمنع التمويه
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .padding()
                        }
                    }
                }
                
                // قسم الانضمام لغرفة
                Divider()
                    .padding(.vertical, 20)

                TextField("Enter Room ID", text: $viewModel.roomID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .keyboardType(.default)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Button(action: {
                 //   viewModel.joinRoom(with: viewModel.roomID)
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

                // زر مسح QR Code
                Button(action: {
                    showingQRScanner = true // فتح شاشة الماسح الضوئي
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
            .navigationBarHidden(true) // إخفاء Navigation Bar الافتراضي
            .onChange(of: viewModel.currentRoom) { newRoom in
                // الانتقال إلى شاشة المحادثة الجديدة عند الانضمام أو الإنشاء بنجاح
                if let room = newRoom, room.id != nil {
                    // هنا ننتقل إلى RoomView
                    // يجب أن يكون لديك `NavigationLink` أو `NavigationStack` في SwiftUI 3+
                    // أو استخدم EnvironmentObject للتنقل إذا كنت تدير تدفق التطبيق مركزياً.
                    Logger.log("Navigating to RoomView for room ID: \(room.id!)", level: .info)
                    // في الوقت الحالي، سنقوم بتحديث appRootManager ليذهب إلى شاشة الغرفة
                    appRootManager.currentView = .room(roomID: room.id!, currentUser: viewModel.authService.user!)
                    
                    // إظهار التنبيه (يمكنك استخدام SwiftUI Alert)
                    // على سبيل المثال:
                    // self.showingJoinSuccessAlert = true
                }
            }
            .sheet(isPresented: $showingQRScanner) {
                // عرض شاشة الماسح الضوئي
             //   QRScannerSheet(delegate: self) // تمرير الـ delegate
                  //  .edgesIgnoringSafeArea(.all)
            }
        }
    }
}

// غلاف بسيط لـ QRCodeScannerView ليعمل مع `sheet`
struct QRScannerSheet: View {
    weak var delegate: QRCodeScannerDelegate?

    var body: some View {
        QRCodeScannerView(delegate: delegate)
    }
}

// تمديد لـ PairingView ليتوافق مع بروتوكول QRCodeScannerDelegate
//extension PairingView: QRCodeScannerDelegate {
//    func didScanQRCode(result: String) {
//        // إغلاق شاشة الماسح الضوئي
//        showingQRScanner = false
//        // استخدام Room ID الممسوح للانضمام إلى الغرفة
//        viewModel.roomID = result // تحديث roomID في ViewModel
//        viewModel.joinRoom(with: result) // بدء عملية الانضمام
//        Logger.log("QR Code scanned: \(result)", level: .info)
//    }
//
//    func scannerDidFail(error: Error) {
//        showingQRScanner = false
//        viewModel.errorMessage = "QR Scanner Failed: \(error.localizedDescription)"
//        Logger.log("QR Scanner failed: \(error.localizedDescription)", level: .error)
//    }
//
//    func scannerDidCancel() {
//        showingQRScanner = false
//        Logger.log("QR Scanner cancelled.", level: .info)
//    }
//}

// قد تحتاج AppRootManager لإدارة التنقل بين الشاشات الرئيسية
// هذا مثال على كيفية تعريفها، وقد تحتاج لتكييفها مع بنية مشروعك


// قم بتحديث User model إذا لم يكن موجودًا
// للتأكد من أن به خاصية `id`
/*
struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var uid: String // قد يكون هو نفسه الـ id
    var email: String?
    var displayName: String?
    // ... أي خصائص أخرى للمستخدم
}
*/
