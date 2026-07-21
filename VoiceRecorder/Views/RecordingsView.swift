import AVFoundation
import SwiftUI

struct RecordingsView: View {
    @EnvironmentObject private var store: RecordingStore
    @Environment(\.editMode) private var editMode
    @State private var selected = Set<Recording.ID>()
    @State private var newFolderName = ""
    @State private var player: AVAudioPlayer?
    @State private var playingRecordingID: Recording.ID?
    @State private var playbackRatesByRecording: [Recording.ID: Float] = [:]
    @State private var playbackProgress: TimeInterval = 0
    @State private var progressTimer: Timer?

    private let playbackRates: [Float] = [1, 1.5, 2]

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
                    let folderRecordings = store.recordings.filter { $0.folderName == folder.name }
                    ForEach(folderRecordings) { recording in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dateFormatter.string(from: recording.createdAt))
                                        .font(.headline)
                                    Text(recording.fileName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Duration: \(Int(recording.duration.rounded())) seconds")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if isEditing {
                                    Button(role: .destructive) {
                                        deleteRecording(recording)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            HStack(spacing: 12) {
                                Button { togglePlayback(for: recording) } label: {
                                    Label(isPlaying(recording) ? "Pause" : "Play", systemImage: isPlaying(recording) ? "pause.fill" : "play.fill")
                                }
                                .buttonStyle(.bordered)

                                Button { cyclePlaybackRate(for: recording) } label: {
                                    Text(playbackRateLabel(for: recording))
                                        .font(.caption.weight(.bold))
                                        .frame(minWidth: 42)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Playback speed")
                                .accessibilityValue(playbackRateLabel(for: recording))
                            }

                            if isPlaying(recording) {
                                Slider(
                                    value: Binding(
                                        get: { playbackProgress },
                                        set: { seek(to: $0) }
                                    ),
                                    in: 0...max(recording.duration, 0.1)
                                )
                                .accessibilityLabel("Playback position")
                            }
                        }
                    }
                    .onDelete { offsets in
                        stopPlayback()
                        store.deleteRecordings(at: offsets, in: folder)
                    }
                } header: {
                    HStack {
                        Text(folder.name)
                        Spacer()
                        if isEditing {
                            Button(role: .destructive) {
                                deleteFolder(folder)
                            } label: {
                                Label("Delete Folder", systemImage: "trash")
                            }
                            .disabled(folder.name == store.currentFolderName && store.folders.count == 1)
                        }
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
        .onDisappear { stopPlayback() }
    }

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    private func playbackRate(for recording: Recording) -> Float {
        playbackRatesByRecording[recording.id] ?? 1
    }

    private func playbackRateLabel(for recording: Recording) -> String {
        let rate = playbackRate(for: recording)
        return rate == 1 ? "1x" : "\(rate.formatted())x"
    }

    private func isPlaying(_ recording: Recording) -> Bool {
        playingRecordingID == recording.id && player?.isPlaying == true
    }

    private func togglePlayback(for recording: Recording) {
        if isPlaying(recording) {
            player?.pause()
            stopProgressTimer()
            return
        }

        do {
            let resumeTime = playingRecordingID == recording.id ? playbackProgress : 0
            player?.stop()
            let audioPlayer = try AVAudioPlayer(contentsOf: recording.url)
            audioPlayer.enableRate = true
            audioPlayer.rate = playbackRate(for: recording)
            audioPlayer.currentTime = resumeTime
            audioPlayer.play()
            player = audioPlayer
            playingRecordingID = recording.id
            playbackProgress = resumeTime
            startProgressTimer()
        } catch {
            stopPlayback()
        }
    }

    private func cyclePlaybackRate(for recording: Recording) {
        let currentRate = playbackRate(for: recording)
        let currentIndex = playbackRates.firstIndex(of: currentRate) ?? 0
        let nextRate = playbackRates[(currentIndex + 1) % playbackRates.count]
        playbackRatesByRecording[recording.id] = nextRate

        if playingRecordingID == recording.id {
            player?.enableRate = true
            player?.rate = nextRate
        }
    }

    private func seek(to time: TimeInterval) {
        playbackProgress = time
        player?.currentTime = time
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            Task { @MainActor in
                guard let player else {
                    stopProgressTimer()
                    return
                }
                playbackProgress = player.currentTime
                if !player.isPlaying {
                    stopProgressTimer()
                    playingRecordingID = nil
                    playbackProgress = 0
                }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        playingRecordingID = nil
        playbackProgress = 0
        stopProgressTimer()
    }

    private func deleteRecording(_ recording: Recording) {
        if playingRecordingID == recording.id {
            stopPlayback()
        }
        selected.remove(recording.id)
        store.deleteRecording(recording)
    }

    private func deleteFolder(_ folder: RecordingFolder) {
        if store.recordings.contains(where: { $0.folderName == folder.name && $0.id == playingRecordingID }) {
            stopPlayback()
        }
        selected.subtract(store.recordings.filter { $0.folderName == folder.name }.map(\.id))
        store.deleteFolder(folder)
    }
}
