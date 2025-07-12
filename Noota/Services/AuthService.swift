// Noota/Services/AuthService.swift
import Foundation
import FirebaseAuth
import FirebaseFirestore // Make sure this is imported for Firestore access
import Combine
import GoogleSignIn
import FirebaseCore

// MARK: - AuthError Enum
// Define AuthError enum here (if it's not already defined elsewhere in your project)
// If you have this in a separate file (e.g., Utilities/Errors.swift), remove this block.
enum AuthError: Error, LocalizedError {
    case invalidEmail
    case wrongPassword
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case invalidCredential
    case unknown(message: String)
    case googleSignInFailed(message: String) // Specific error for Google Sign-In issues
    case firestoreError(message: String) // Specific error for Firestore issues

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "The email address is not valid."
        case .wrongPassword:
            return "The password you entered is incorrect."
        case .userNotFound:
            return "No user found with this email."
        case .emailAlreadyInUse:
            return "This email address is already in use."
        case .weakPassword:
            return "The password is too weak. It must be at least 6 characters."
        case .invalidCredential:
            return "Invalid credentials provided."
        case .unknown(let message):
            return message
        case .googleSignInFailed(let message):
            return "Google Sign-In failed: \(message)"
        case .firestoreError(let message):
            return "Firestore operation failed: \(message)"
        }
    }
}

// MARK: - AuthService Class
class AuthService: ObservableObject {
    @Published var user: User? // You need to have the 'User' struct defined.
    @Published var isAuthenticated: Bool = false
    @Published var isInitialAuthCheckComplete: Bool = false
    
    private var authStateDidChangeListenerHandle: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    
    private let db = Firestore.firestore() // For saving to Firestore

    init() {
        setupAuthStateListener()
        
        // This is crucial for Google Sign-In to work. Configure it once.
        // It's generally best to do this in AppDelegate's didFinishLaunchingWithOptions,
        // but if done here, ensure it runs only once.
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            Logger.log("Firebase clientID not found for Google Sign-In configuration.", level: .error)
        }
    }

    deinit {
        if let handle = authStateDidChangeListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        cancellables.removeAll()
        Logger.log("AuthService deinitialized.", level: .info)
    }

    private func setupAuthStateListener() {
        authStateDidChangeListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, firebaseUser in
            guard let self = self else { return }
            
            if let firebaseUser = firebaseUser {
                // On sign-in or app launch, try to fetch user data from Firestore
                self.fetchUserFromFirestore(uid: firebaseUser.uid)
                    .sink { completion in
                        if case .failure(let error) = completion {
                            Logger.log("Error fetching user data from Firestore: \(error.localizedDescription)", level: .error)
                            // If fetching from Firestore fails, create a basic User object
                            self.user = User(uid: firebaseUser.uid, email: firebaseUser.email, firstName: firebaseUser.displayName?.components(separatedBy: " ").first, lastName: firebaseUser.displayName?.components(separatedBy: " ").dropFirst().joined(separator: " "))
                        }
                        self.isAuthenticated = (self.user != nil) // Update auth status based on user presence
                        self.isInitialAuthCheckComplete = true
                    } receiveValue: { appUser in
                        self.user = appUser
                        Logger.log("User data loaded from Firestore: \(appUser?.email ?? "N/A")", level: .info)
                        self.isAuthenticated = (self.user != nil)
                        self.isInitialAuthCheckComplete = true
                    }
                    .store(in: &self.cancellables) // Store the subscription
            } else {
                self.user = nil
                self.isAuthenticated = false
                Logger.log("User signed out or no user.", level: .info)
                self.isInitialAuthCheckComplete = true
            }
        }
    }

    func signIn(email: String, password: String) -> AnyPublisher<User, Error> {
        return Future<User, Error> { promise in
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    let authError = self.handleAuthError(error as NSError)
                    Logger.log("Sign In Error: \(authError.localizedDescription)", level: .error)
                    promise(.failure(authError))
                    return
                }
                
                guard let firebaseUser = authResult?.user else {
                    promise(.failure(AuthError.unknown(message: "Unknown error during sign-in.")))
                    return
                }
                
                // After sign-in, fetch user data from Firestore
                self.fetchUserFromFirestore(uid: firebaseUser.uid)
                    .sink { completion in
                        if case .failure(let fetchError) = completion {
                            Logger.log("Error fetching user data after sign-in: \(fetchError.localizedDescription)", level: .error)
                            // If fetch fails, create a basic User to proceed
                            let appUser = User(uid: firebaseUser.uid, email: firebaseUser.email, firstName: firebaseUser.displayName?.components(separatedBy: " ").first, lastName: firebaseUser.displayName?.components(separatedBy: " ").dropFirst().joined(separator: " "))
                            self.user = appUser
                            promise(.success(appUser))
                        }
                    } receiveValue: { appUser in
                        guard let appUser = appUser else {
                            promise(.failure(AuthError.unknown(message: "Failed to load user data after sign-in.")))
                            return
                        }
                        self.user = appUser
                        promise(.success(appUser))
                    }
                    .store(in: &self.cancellables)
            }
        }
        .eraseToAnyPublisher()
    }

    func signUp(email: String, password: String, firstName: String, lastName: String) -> AnyPublisher<User, Error> {
        return Future<User, Error> { promise in
            Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    let authError = self.handleAuthError(error as NSError)
                    Logger.log("Sign Up Error: \(authError.localizedDescription)", level: .error)
                    promise(.failure(authError))
                    return
                }
                
                guard let firebaseUser = authResult?.user else {
                    promise(.failure(AuthError.unknown(message: "Unknown error during sign-up.")))
                    return
                }
                
                let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 1. Update user profile in Firebase Auth
                let changeRequest = firebaseUser.createProfileChangeRequest()
                changeRequest.displayName = displayName
                changeRequest.commitChanges { error in
                    if let error = error {
                        Logger.log("Error updating Firebase Auth profile: \(error.localizedDescription)", level: .error)
                        // Don't stop the process here, but log the error
                    }
                    
                    // 2. Create our custom User object
                    let appUser = User(uid: firebaseUser.uid, email: firebaseUser.email, firstName: firstName, lastName: lastName)
                    
                    // 3. Save additional user data to Firestore
                    do {
                        try self.db.collection("users").document(firebaseUser.uid).setData(from: appUser) { firestoreError in
                            if let firestoreError = firestoreError {
                                promise(.failure(AuthError.firestoreError(message: "Failed to save user data to Firestore: \(firestoreError.localizedDescription)")))
                            } else {
                                self.user = appUser // Update the published user
                                Logger.log("User signed up and data saved to Firestore: \(appUser.email ?? "")", level: .info)
                                promise(.success(appUser))
                            }
                        }
                    } catch {
                        promise(.failure(AuthError.firestoreError(message: "Error encoding user data for Firestore: \(error.localizedDescription)")))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // here we start function of signin with google but it has problem now it need to be fixed
    func signInWithGoogle() -> AnyPublisher<User, Error> {
        return Future<User, Error> { promise in
            guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
                    .windows.first?.rootViewController else {
                promise(.failure(AuthError.unknown(message: "Could not find presenting view controller for Google Sign In.")))
                return
            }

            // The GIDConfiguration is already set in init(), but re-confirming here for clarity.
            // If it's nil, it indicates a problem with FirebaseApp.app()?.options.clientID
            guard GIDSignIn.sharedInstance.configuration != nil else {
                promise(.failure(AuthError.googleSignInFailed(message: "Google Sign-In configuration missing. Check Firebase setup.")))
                return
            }

            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { signInResult, error in
                if let error = error {
                    Logger.log("Google Sign-In Error: \(error.localizedDescription)", level: .error)
                    // If the user cancels, GoogleSignIn might return a specific error code.
                    // You might want to handle user cancellation separately.
                    if let googleSignInError = error as? GIDSignInError {
                        if googleSignInError.code == .canceled {
                            promise(.failure(AuthError.googleSignInFailed(message: "Google Sign-In cancelled by user.")))
                            return
                        }
                    }
                    promise(.failure(error)) // Propagate other Google Sign-In errors
                    return
                }
                
                guard let user = signInResult?.user,
                      let idToken = user.idToken?.tokenString else {
                    Logger.log("Google Sign-In: Missing ID Token.", level: .error)
                    promise(.failure(AuthError.unknown(message: "Google Sign-In: Missing ID Token.")))
                    return
                }
                
                // AccessToken is often not strictly needed for Firebase Auth with ID Token,
                // but if used, ensure you access .tokenString.
                let accessToken = user.accessToken.tokenString
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                               accessToken: accessToken)
                
                Auth.auth().signIn(with: credential) { authResult, firebaseError in
                    if let firebaseError = firebaseError {
                        Logger.log("Firebase Google Auth Error: \(firebaseError.localizedDescription)", level: .error)
                        promise(.failure(firebaseError))
                        return
                    }
                    
                    guard let firebaseUser = authResult?.user else {
                        Logger.log("Firebase Google Auth: No user found after sign-in.", level: .error)
                        promise(.failure(AuthError.unknown(message: "Firebase Google Auth: No user found.")))
                        return
                    }
                    
                    // If this is the first Google sign-in, create a user profile in Firestore
                    self.fetchUserFromFirestore(uid: firebaseUser.uid)
                        .flatMap { existingUser -> AnyPublisher<User, Error> in
                            if let existingUser = existingUser {
                                Logger.log("Google user already exists: \(existingUser.email ?? "")", level: .info)
                                return Just(existingUser).setFailureType(to: Error.self).eraseToAnyPublisher()
                            } else {
                                let newUser = User(
                                    uid: firebaseUser.uid,
                                    email: firebaseUser.email,
                                    // Use Google's provided display name for first/last if available
                                    firstName: firebaseUser.displayName?.components(separatedBy: " ").first,
                                    lastName: firebaseUser.displayName?.components(separatedBy: " ").dropFirst().joined(separator: " ")
                                )
                                Logger.log("Creating new Google user profile for: \(newUser.email ?? "")", level: .info)
                                return self.createUserInFirestore(user: newUser)
                            }
                        }
                        .sink { completion in
                            if case .failure(let createUserError) = completion {
                                Logger.log("Error handling Google user Firestore profile: \(createUserError.localizedDescription)", level: .error)
                                promise(.failure(createUserError))
                            }
                        } receiveValue: { appUser in
                            self.user = appUser // Update the published user
                            promise(.success(appUser))
                        }
                        .store(in: &self.cancellables)
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.isAuthenticated = false // Set isAuthenticated to false on signOut
            Logger.log("User signed out.", level: .info)
        } catch let signOutError as NSError {
            throw AuthError.unknown(message: "Error signing out: \(signOutError.localizedDescription)")
        }
    }

    // MARK: - Firestore Helper Functions
    private func fetchUserFromFirestore(uid: String) -> AnyPublisher<User?, Error> {
        return Future<User?, Error> { promise in
            self.db.collection("users").document(uid).getDocument(as: User.self) { result in
                switch result {
                case .success(let user):
                    promise(.success(user))
                case .failure(let error):
                    // If the document doesn't exist, result is .failure but user should be nil not error
                    // FirestoreDataDecoder.Error.documentNotFound is common here
                    if let decodingError = error as? DecodingError, case .dataCorrupted(let context) = decodingError {
                        if context.debugDescription.contains("document not found") {
                            promise(.success(nil)) // No user found in Firestore, not an error
                            return
                        }
                    }
                    Logger.log("Failed to fetch user data from Firestore for UID \(uid): \(error.localizedDescription)", level: .error)
                    promise(.failure(AuthError.firestoreError(message: "Failed to fetch user data: \(error.localizedDescription)")))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func createUserInFirestore(user: User) -> AnyPublisher<User, Error> {
        return Future<User, Error> { promise in
            do {
                try self.db.collection("users").document(user.uid).setData(from: user) { error in
                    if let error = error {
                        promise(.failure(AuthError.firestoreError(message: "Failed to save user data to Firestore: \(error.localizedDescription)")))
                    } else {
                        promise(.success(user))
                    }
                }
            } catch {
                promise(.failure(AuthError.firestoreError(message: "Error encoding user data for Firestore: \(error.localizedDescription)")))
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Error Handling
    private func handleAuthError(_ error: NSError) -> AuthError {
        // Converts Firebase Auth error codes to your custom AuthError
        switch AuthErrorCode(rawValue: error.code) {
        case .invalidEmail:
            return .invalidEmail
        case .wrongPassword:
            return .wrongPassword
        case .userNotFound:
            return .userNotFound
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .invalidCredential:
            return .invalidCredential
        default:
            return .unknown(message: error.localizedDescription)
        }
    }
}
