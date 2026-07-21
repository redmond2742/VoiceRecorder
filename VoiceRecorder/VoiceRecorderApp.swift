import SwiftUI

@main
struct VoiceRecorderApp: App {
    @StateObject private var store = RecordingStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(settings)
        }
    }
}
