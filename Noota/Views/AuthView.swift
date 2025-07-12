// Noota/Views/AuthView.swift
import SwiftUI
import Combine

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showingSignUp = false // للتحكم في عرض حقول التسجيل
    
    @State private var viewCancellables = Set<AnyCancellable>()
    
    // لإدارة حالة الخطأ والعرض
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            ZStack {
                // خلفية متدرجة تتطابق مع MainAppView
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer() // يدفع المحتوى للأسفل قليلاً

                    // شعار Noota
                    Text("Noota")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
                        .padding(.bottom, 30)

                    // عنوان الشاشة
                    Text(showingSignUp ? "Create Your Account" : "Sign In")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.bottom, 20)
                    
                    VStack(spacing: 15) { // حاوية لحقول الإدخال والأزرار
                        // حقول الاسم الأول والأخير تظهر فقط عند التسجيل
                        if showingSignUp {
                            ZStack(alignment: .leading) {
                                if firstName.isEmpty {
                                    Text("First Name")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 8)
                                }
                                TextField("", text: $firstName)
                            }
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                            .autocapitalization(.words)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                            .foregroundColor(.black)
                            .accentColor(.blue)

                            ZStack(alignment: .leading) {
                                if lastName.isEmpty {
                                    Text("Last Name")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 8)
                                }
                                TextField("", text: $lastName)
                            }
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                            .autocapitalization(.words)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                            .foregroundColor(.black)
                            .accentColor(.blue)
                        }

                        ZStack(alignment: .leading) {
                            if email.isEmpty {
                                Text("Email")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)
                            }
                            TextField("", text: $email)
                        }
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                        .foregroundColor(.black)
                        .accentColor(.blue)

                        ZStack(alignment: .leading) {
                            if password.isEmpty {
                                Text("Password")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)
                            }
                            SecureField("", text: $password)
                        }
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                        .foregroundColor(.black)
                        .accentColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    // زر الإجراء الرئيسي (Sign In / Create Account)
                    Button {
                        if showingSignUp {
                            authService.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
                                .sink(receiveCompletion: { completion in
                                    if case .failure(let error) = completion {
                                        self.alertMessage = error.localizedDescription
                                        self.showAlert = true
                                        Logger.log("Sign Up Error: \(error.localizedDescription)", level: .error)
                                    }
                                }, receiveValue: { user in
                                    Logger.log("Signed Up: \(user.email ?? "")", level: .info)
                                })
                                .store(in: &viewCancellables)
                        } else {
                            authService.signIn(email: email, password: password)
                                .sink(receiveCompletion: { completion in
                                    if case .failure(let error) = completion {
                                        self.alertMessage = error.localizedDescription
                                        self.showAlert = true
                                        Logger.log("Sign In Error: \(error.localizedDescription)", level: .error)
                                    }
                                }, receiveValue: { user in
                                    Logger.log("Signed In: \(user.email ?? "")", level: .info)
                                })
                                .store(in: &viewCancellables)
                        }
                    } label: {
                        Text(showingSignUp ? "Create Account" : "Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(showingSignUp ? LinearGradient(gradient: Gradient(colors: [Color.green, Color.teal]), startPoint: .leading, endPoint: .trailing) : LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(15)
                            .shadow(radius: 5)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    // قسم أيقونات تسجيل الدخول الاجتماعي
                    VStack {
                        Text("- Or -")
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.7))
                            .padding(.vertical, 10)

                        HStack(spacing: 30) {
                            // أيقونة Apple
                            Button {
                                // ✨ جديد: رسالة لـ Apple Sign-In
                                self.alertMessage = "Sign In with Apple is not yet available."
                                self.showAlert = true
                                Logger.log("Apple Sign-In button pressed - Not available.", level: .info)
                            } label: {
                                Image(systemName: "apple.logo")
                                    .font(.title2) // أو الحجم الذي تفضله
                                    .foregroundColor(.black)
                                    .padding(12)
                                    .background(Circle().fill(Color.white).shadow(radius: 3))
                            }

                            // أيقونة Google
                            Button {
                                // ✨ جديد: استدعاء دالة تسجيل الدخول بـ Google
                                authService.signInWithGoogle()
                                    .sink(receiveCompletion: { completion in
                                        if case .failure(let error) = completion {
                                            self.alertMessage = error.localizedDescription
                                            self.showAlert = true
                                            Logger.log("Google Sign-In Error (UI): \(error.localizedDescription)", level: .error)
                                        }
                                    }, receiveValue: { user in
                                        Logger.log("Successfully signed in with Google: \(user.email ?? "")", level: .info)
                                        // سيتم الانتقال تلقائياً بواسطة RootView
                                    })
                                    .store(in: &viewCancellables)
                            } label: {
                                Image("googleLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 35, height: 35)
                                    .padding(8)
                                    .background(Circle().fill(Color.white).shadow(radius: 3))
                            }
                        }
                    }
                    .padding(.top, 20)


                    // زر التبديل بين Sign In و Sign Up
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSignUp.toggle()
                            email = ""
                            password = ""
                            firstName = ""
                            lastName = ""
                            alertMessage = ""
                        }
                    } label: {
                        Text(showingSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.subheadline)
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Authentication Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onDisappear {
                viewCancellables.removeAll()
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthService())
    }
}
