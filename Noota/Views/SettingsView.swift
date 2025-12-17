// Noota/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject var viewModel: SettingsViewModel
    @State private var showVoiceRegistration = false
    @State private var showNameEditAlert = false
    @State private var newName = ""
    @State private var isDarkMode: Bool = false
    
    init(authService: AuthService) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(authService: authService))
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    
                    // Profile Settings Card
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                            Text("Profile")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        // Name Display and Edit
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Full Name")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack {
                                Text(viewModel.userName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: {
                                    newName = viewModel.userName
                                    showNameEditAlert = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundColor(.blue.opacity(0.8))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.2))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )
                    .padding(.horizontal, 20)
                    
                    // Voice Profile Card
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.orange)
                            Text("Voice Profile")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        if viewModel.hasVoiceProfile {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Voice Profile Ready")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Text("Your voice will be used for translations")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("No Voice Profile")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Text("Record your voice for personalized synthesis")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        Button(action: { showVoiceRegistration = true }) {
                            HStack {
                                Image(systemName: viewModel.hasVoiceProfile ? "arrow.2.circlepath" : "mic")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(viewModel.hasVoiceProfile ? "Re-record Voice" : "Record Voice")
                                    .font(.headline)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.red.opacity(0.6)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.2))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )
                    .padding(.horizontal, 20)
                    
                    // Language Settings Card
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: "globe")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                            Text("Language")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        Picker("App Language", selection: $viewModel.selectedLanguage) {
                            ForEach(viewModel.availableLanguages, id: \.self) { language in
                                Text(viewModel.getLanguageName(language))
                                    .tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                        .onChange(of: viewModel.selectedLanguage) { oldValue, newValue in
                            viewModel.saveLanguagePreference(newValue)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.2))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )
                    .padding(.horizontal, 20)
                    
                    // Appearance Settings Card
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.purple)
                            Text("Appearance")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        HStack {
                            Text("Dark Mode")
                                .foregroundColor(.white)
                            Spacer()
                            Toggle("", isOn: $isDarkMode)
                                .onChange(of: isDarkMode) { oldValue, newValue in
                                    viewModel.setDarkMode(newValue)
                                }
                                .onAppear {
                                    isDarkMode = viewModel.isDarkMode
                                }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.2))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )
                    .padding(.horizontal, 20)
                    
                    // About Card
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.cyan)
                            Text("About")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        HStack {
                            Text("App Version")
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text("2.0.0-beta")
                                .font(.subheadline)
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.2))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer()
                        .frame(height: 20)
                }
            }
        }
        .alert("Edit Name", isPresented: $showNameEditAlert) {
            TextField("Enter new name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                viewModel.updateUserName(newName)
            }
        }
        .sheet(isPresented: $showVoiceRegistration) {
            VoiceRegistrationView(viewModel: viewModel, isPresented: $showVoiceRegistration)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockAuthService = AuthService()
        SettingsView(authService: mockAuthService)
            .environmentObject(mockAuthService)
    }
}
