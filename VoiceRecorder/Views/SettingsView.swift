import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Recording length") {
                Picker("Limit", selection: $settings.recordingLimit) {
                    ForEach(AppSettings.durationOptions, id: \.self) { seconds in
                        Text(label(for: seconds)).tag(seconds)
                    }
                }
            }

            Section("Question order") {
                Picker("Mode", selection: $settings.questionMode) {
                    ForEach(QuestionMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("City questions") {
                ForEach(settings.questions.indices, id: \.self) { index in
                    TextField("Question", text: Binding(
                        get: { settings.questions[index] },
                        set: { settings.questions[index] = $0 }
                    ), axis: .vertical)
                }
                .onDelete { settings.questions.remove(atOffsets: $0) }
                .onMove { settings.questions.move(fromOffsets: $0, toOffset: $1) }

                Button { settings.questions.append("") } label: {
                    Label("Add Question", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar { EditButton() }
    }

    private func label(for seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) seconds" }
        if seconds % 60 == 0 { return "\(seconds / 60) minutes" }
        return "\(seconds / 60) min \(seconds % 60) sec"
    }
}
