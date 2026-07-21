import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: RecordingStore
    @EnvironmentObject private var settings: AppSettings
    @State private var prompt = "What do you love most about your city?"
    @State private var secondsRemaining = 45
    @State private var timer: Timer?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    Text("City Prompt")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(prompt)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue.opacity(0.08))

                VStack(spacing: 24) {
                    if store.isRecording {
                        Text("\(secondsRemaining)")
                            .font(.system(size: 104, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                            .accessibilityLabel("\(secondsRemaining) seconds remaining")
                        Button("Stop", role: .destructive) { stopRecording() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                    } else {
                        Button(action: startRecording) {
                            ZStack {
                                Circle().fill(.red)
                                Text("START")
                                    .font(.system(size: 38, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 220, height: 220)
                            .shadow(radius: 10)
                        }
                        .accessibilityLabel("Start recording")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
            .navigationTitle("Voice Recorder")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink("Recordings") { RecordingsView() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                }
            }
            .alert("Recording Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                secondsRemaining = settings.recordingLimit
                prompt = settings.previewQuestion
            }
        }
    }

    private func startRecording() {
        prompt = settings.nextQuestion()
        secondsRemaining = settings.recordingLimit
        Task {
            do {
                try await store.start(prompt: prompt)
                guard store.isRecording else { return }
                startCountdown()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startCountdown() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsRemaining <= 1 {
                stopRecording()
            } else {
                secondsRemaining -= 1
            }
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        store.stop()
        secondsRemaining = settings.recordingLimit
    }
}
