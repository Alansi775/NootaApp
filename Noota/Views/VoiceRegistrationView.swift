// Noota/Views/VoiceRegistrationView.swift
import SwiftUI
import AVFoundation

struct VoiceRegistrationView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var isPresented: Bool
    @State private var currentStep: VoiceRegistrationStep = .selectLanguage
    @State private var selectedLanguage: String = "en"
    @State private var isRecording = false
    @State private var recordingTime: Int = 0
    @State private var countdown: Int = 3
    @State private var isCountingDown = false
    @State private var showTimer = false
    @State private var uploadProgress: Double = 0
    @State private var alertMessage: String = ""
    @State private var showAlert = false
    
    enum VoiceRegistrationStep {
        case selectLanguage
        case readInstructions
        case recording
        case uploading
        case success
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Text("Voice Profile Setup")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                
                // Step indicator
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(index <= stepIndex() ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 8)
                    }
                }
                // Content based on current step
                switch currentStep {
                case .selectLanguage:
                    selectLanguageView
                case .readInstructions:
                    readInstructionsView
                case .recording:
                    recordingView
                case .uploading:
                    uploadingView
                case .success:
                    successView
                }
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: 15) {
                    if currentStep != .selectLanguage && currentStep != .success {
                        Button(action: previousStep) {
                            Text("Back")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.6))
                                .cornerRadius(10)
                        }
                    }
                    
                    if currentStep != .uploading && currentStep != .success {
                        Button(action: nextStep) {
                            Text(currentStep == .recording ? "Done" : "Next")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                        }
                        .disabled(isCountingDown)
                    } else if currentStep == .success {
                        Button(action: { isPresented = false }) {
                            Text("Close")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(25)
            .padding()
        }
        .alert("Voice Registration", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onDisappear {
            if isRecording {
                viewModel.stopVoiceRecording()
            }
        }
    }
    
    // MARK: - Steps Views
    
    private var selectLanguageView: some View {
        VStack(spacing: 20) {
            Text("Select Language")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundColor(.white)
            
            Text("Choose your preferred language")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Picker("Language", selection: $selectedLanguage) {
                ForEach(viewModel.availableLanguages, id: \.self) { language in
                    Text(viewModel.getLanguageName(language))
                        .tag(language)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
        }
        .padding()
    }
    
    private var readInstructionsView: some View {
        VStack(spacing: 15) {
            Text("Instructions")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundColor(.white)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    instructionItem(
                        number: "1",
                        title: "Environment",
                        description: "Find a quiet place with minimal background noise"
                    )
                    instructionItem(
                        number: "2",
                        title: "Microphone",
                        description: "Hold your device close to your mouth for best quality"
                    )
                    instructionItem(
                        number: "3",
                        title: "Reading",
                        description: "You will read a provided text clearly and naturally"
                    )
                    instructionItem(
                        number: "4",
                        title: "Duration",
                        description: "Recording will be exactly 60 seconds long"
                    )
                    instructionItem(
                        number: "5",
                        title: "Privacy",
                        description: "Your voice will only be used for translation purposes"
                    )
                }
            }
            
            Text("Tap Next to continue")
                .font(.caption)
                .foregroundColor(.blue.opacity(0.8))
        }
        .padding()
    }
    
    private var recordingView: some View {
        VStack(spacing: 20) {
            if showTimer {
                VStack(spacing: 10) {
                    Text("Recording in...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(countdown)")
                        .font(.system(size: 60, weight: .bold, design: .default))
                        .foregroundColor(.blue)
                }
                .onAppear {
                    startCountdown()
                }
            } else if isRecording {
                VStack(spacing: 20) {
                    Text("Reading Text")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    
                    ScrollView {
                        Text(viewModel.getVoiceRegistrationText(for: selectedLanguage))
                            .font(.body)
                            .lineSpacing(8)
                            .foregroundColor(.white.opacity(0.9))
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                    }
                    .frame(maxHeight: 150)
                    
                    // Recording indicators
                    VStack(spacing: 10) {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                            Text("Recording")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            Spacer()
                            Text(formattedTime(recordingTime))
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundColor(.red)
                        }
                        
                        ProgressView(value: Double(recordingTime) / 60.0)
                            .tint(.red)
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue.opacity(0.8))
                    
                    Text("Ready to Record")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Tap Next to start recording")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding()
    }
    
    private var uploadingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.upload.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Uploading Voice Profile")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            
            ProgressView(value: uploadProgress)
                .tint(.blue)
            
            Text("\(Int(uploadProgress * 100))%")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
    }
    
    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Success")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Your voice profile has been saved successfully and will be used for translation.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Views
    
    private func instructionItem(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(Text(number).font(.caption).fontWeight(.bold).foregroundColor(.white))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func stepIndex() -> Int {
        switch currentStep {
        case .selectLanguage: return 0
        case .readInstructions: return 1
        case .recording: return 2
        case .uploading: return 3
        case .success: return 4
        }
    }
    
    private func nextStep() {
        switch currentStep {
        case .selectLanguage:
            currentStep = .readInstructions
        case .readInstructions:
            currentStep = .recording
            startRecording()
        case .recording:
            stopRecording()
            currentStep = .uploading
            uploadVoiceProfile()
        case .uploading:
            break
        case .success:
            break
        }
    }
    
    private func previousStep() {
        if isRecording {
            viewModel.stopVoiceRecording()
            isRecording = false
        }
        
        switch currentStep {
        case .selectLanguage:
            break
        case .readInstructions:
            currentStep = .selectLanguage
        case .recording:
            currentStep = .readInstructions
        case .uploading:
            currentStep = .recording
        case .success:
            break
        }
    }
    
    private func startRecording() {
        showTimer = true
    }
    
    private func startCountdown() {
        isCountingDown = true
        countdown = 3
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdown -= 1
            if countdown < 0 {
                timer.invalidate()
                isCountingDown = false
                showTimer = false
                isRecording = true
                recordingTime = 0
                viewModel.startVoiceRecording(language: selectedLanguage)
                
                // Start recording timer
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { recordingTimer in
                    if isRecording && recordingTime < 60 {
                        recordingTime += 1
                    } else if recordingTime >= 60 {
                        recordingTimer.invalidate()
                        stopRecording()
                        currentStep = .uploading
                        uploadVoiceProfile()
                    }
                }
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        viewModel.stopVoiceRecording()
    }
    
    private func uploadVoiceProfile() {
        Task {
            do {
                // Simulate upload progress
                for i in 0...100 {
                    uploadProgress = Double(i) / 100.0
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }
                
                try await viewModel.uploadVoiceProfile(language: selectedLanguage)
                currentStep = .success
            } catch {
                alertMessage = "Upload failed: \(error.localizedDescription)"
                showAlert = true
                currentStep = .recording
            }
        }
    }
    
    private func formattedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

struct VoiceRegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        @State var isPresented = true
        let mockAuthService = AuthService()
        let mockViewModel = SettingsViewModel(authService: mockAuthService)
        
        VoiceRegistrationView(viewModel: mockViewModel, isPresented: $isPresented)
    }
}
