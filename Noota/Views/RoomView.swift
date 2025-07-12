// Noota/Views/RoomView.swift هذا
import SwiftUI

struct RoomView: View {
    let room: Room
    let currentUser: User
    let opponentName: String

    var body: some View {
        VStack {
            Spacer()
            
            Text("Welcome to the Room!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 20)

            Text("You are connected with:")
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))

            Text(opponentName)
                .font(.system(size: 45, weight: .bold, design: .rounded))
                .foregroundColor(.green)
                .padding(.vertical, 10)
                .multilineTextAlignment(.center)

            Text("Room ID: \(room.id ?? "N/A")")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 5)

            Button {
                // منطق الخروج من الغرفة
                // يمكنك استدعاء دالة في PairingViewModel أو FirestoreService
                // لإزالة المستخدم من الغرفة أو إنهاء الغرفة
                Logger.log("Attempting to leave room \(room.id ?? "N/A")", level: .info)
                // للعودة إلى MainAppView، ستحتاج إلى طريقة لإغلاق الـ RoomView
                // يمكنك استخدام @Environment(\.dismiss) أو تعيين currentRoom في PairingViewModel إلى nil
                // مثال على استخدام dismiss (إذا كنت على iOS 15+):
                // @Environment(\.dismiss) var dismiss
                // dismiss()
            } label: {
                Text("Leave Room")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
            .padding(.top, 40)
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .navigationBarHidden(true)
    }
}

struct RoomView_Previews: PreviewProvider {
    static var previews: some View {
        let mockRoom = Room(
            id: "PREVIEW_ROOM_ID",
            hostUserID: "host123",
            participantUIDs: ["host123", "participant456"],
            status: .active
        )
        let mockCurrentUser = User(uid: "host123", email: "host@example.com", firstName: "HostName", lastName: "")
        let mockOpponentName = "ParticipantName"

        RoomView(room: mockRoom, currentUser: mockCurrentUser, opponentName: mockOpponentName)
            .environmentObject(AuthService())
            .environmentObject(FirestoreService())
    }
}
