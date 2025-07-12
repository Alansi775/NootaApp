// Noota/Views/RootView.swift
import SwiftUI

struct RootView: View {
    @StateObject var authService = AuthService()
    // FirestoreService يمكن أن تكون هنا كـ @StateObject أيضاً إذا كانت بحاجة للمراقبة،
    // لكن بما أنها ثابتة هنا، private let مناسبة.
    private let firestoreService = FirestoreService()

    var body: some View {
        Group {
            if authService.isInitialAuthCheckComplete { // ✨ جديد: نتحقق أولاً إذا كان التحقق الأولي قد اكتمل
                if authService.user != nil {
                    MainAppView(authService: authService, firestoreService: firestoreService)
                        .environmentObject(authService)
                        .environmentObject(firestoreService)
                } else {
                    AuthView()
                        .environmentObject(authService)
                }
            } else {
                // ✨ جديد: شاشة تحميل بسيطة أو فارغة أثناء التحقق الأولي
                Color.black.ignoresSafeArea() // يمكن أن تكون شاشة تحميل كاملة أو Logo
                // أو يمكنك استخدام ProgressView()
                // ProgressView()
                //     .scaleEffect(2) // كبر مؤشر التحميل
                //     .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            }
        }
        .onAppear {
            Logger.log("RootView appeared. User: \(authService.user?.email ?? "nil")", level: .info)
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
