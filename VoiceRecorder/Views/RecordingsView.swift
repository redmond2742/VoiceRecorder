import SwiftUI

struct RecordingsView: View {
    @EnvironmentObject private var store: RecordingStore
    @State private var selected = Set<Recording.ID>()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        List(store.recordings, selection: $selected) { recording in
            VStack(alignment: .leading, spacing: 6) {
                Text(dateFormatter.string(from: recording.createdAt))
                    .font(.headline)
                Text(recording.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Duration: \(Int(recording.duration.rounded())) seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Recordings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
            ToolbarItem(placement: .bottomBar) {
                ShareLink(items: store.exportURLs(for: selected)) {
                    Label(selected.isEmpty ? "Export All" : "Export Selected", systemImage: "square.and.arrow.up")
                }
                .disabled(store.recordings.isEmpty)
            }
        }
        .overlay {
            if store.recordings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "mic")
                        .font(.largeTitle)
                    Text("No Recordings")
                        .font(.headline)
                    Text("Start a city prompt recording to create your first clip.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
