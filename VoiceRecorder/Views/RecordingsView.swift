import SwiftUI

struct RecordingsView: View {
    @EnvironmentObject private var store: RecordingStore
    @State private var selected = Set<Recording.ID>()
    @State private var newFolderName = ""

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        List(selection: $selected) {
            Section("Default recording folder") {
                Picker("Record to", selection: Binding(
                    get: { store.currentFolderName },
                    set: { store.setCurrentFolder($0) }
                )) {
                    ForEach(store.folders) { folder in
                        Text(folder.name).tag(folder.name)
                    }
                }

                HStack {
                    TextField("New folder", text: $newFolderName)
                    Button("Create") {
                        store.createFolder(named: newFolderName)
                        newFolderName = ""
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            ForEach(store.folders) { folder in
                Section {
                    ForEach(store.recordings.filter { $0.folderName == folder.name }) { recording in
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
                } header: {
                    HStack {
                        Text(folder.name)
                        Spacer()
                        ShareLink(items: store.exportURLs(forFolder: folder)) {
                            Label("Export Folder", systemImage: "square.and.arrow.up")
                        }
                        .disabled(store.exportURLs(forFolder: folder).isEmpty)
                    }
                }
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
                    Text("Start a city prompt recording to create your first MP3 clip.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
