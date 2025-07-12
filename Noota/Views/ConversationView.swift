// Noota/Views/ConversationView.swift
import SwiftUI

struct ConversationView: View {
    let room: Room
    let currentUser: User
    let opponentUser: User // هذا الآن كائن User كامل
    @ObservedObject var pairingVM: PairingViewModel // للاستماع إلى تغييرات الغرفة أو للتعامل مع مغادرة الغرفة

    var body: some View {
        VStack {
            Text("Conversation with \(opponentUser.firstName ?? opponentUser.email ?? "Opponent")")
                .font(.largeTitle)
                .padding()

            Text("Room ID: \(room.id ?? "N/A")")
                .font(.headline)
                .foregroundColor(.gray)
            
            // هنا ستضع واجهة المستخدم الخاصة بالمحادثة (الرسائل، حقل إدخال النص، زر الإرسال)
            Spacer()
            
            Button("Leave Room") {
                Task { @MainActor in
                    await pairingVM.leaveCurrentRoom()
                }
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .navigationTitle("")
        .navigationBarHidden(true) // إخفاء شريط التنقل الافتراضي إذا كنت تريد شريطًا مخصصًا
        .onAppear {
            Logger.log("ConversationView appeared for room: \(room.id ?? "N/A")", level: .info)
            Logger.log("Current user: \(currentUser.firstName ?? "N/A"), Opponent: \(opponentUser.firstName ?? "N/A")", level: .info)
        }
    }

    // لكي تتمكن من معاينة ConversationView
    struct ConversationView_Previews: PreviewProvider {
        static var previews: some View {
            // بيانات وهمية للمعاين
            // 💡 التعديلات هنا:
            // 1. تغيير 'id' إلى 'uid'
            // 2. إضافة 'lastName: nil' أو أي قيمة افتراضية إذا كانت مطلوبة وليست اختيارية
            let mockCurrentUser = User(uid: "user1", email: "user1@example.com", firstName: "Alice", lastName: nil)
            let mockOpponentUser = User(uid: "user2", email: "user2@example.com", firstName: "Bob", lastName: nil)
            let mockRoom = Room(id: "mockRoom123", hostUserID: "user1", participantUIDs: ["user1", "user2"], status: .active)
            
            // تحتاج إلى تمرير FirestoreService و AuthService لـ PairingViewModel
            let mockFirestoreService = FirestoreService()
            let mockAuthService = AuthService()
            let mockPairingVM = PairingViewModel(firestoreService: mockFirestoreService, authService: mockAuthService)

            ConversationView(room: mockRoom, currentUser: mockCurrentUser, opponentUser: mockOpponentUser, pairingVM: mockPairingVM)
                .environmentObject(mockAuthService)
                .environmentObject(mockFirestoreService)
        }
    }
}
