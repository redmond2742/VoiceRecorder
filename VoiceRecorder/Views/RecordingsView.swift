import AVFoundation
import SwiftUI

struct RecordingsView: View {
    @EnvironmentObject private var store: RecordingStore
    @State private var selected = Set<Recording.ID>()
    @State private var newFolderName = ""
    @State private var player: AVAudioPlayer?
    @State private var playingRecordingID: Recording.ID?
    @State private var playbackRate: Float = 1

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
                    ForEach(store.recordings.filter { $0.folderName == folder.name }) { recording in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(dateFormatter.string(from: recording.createdAt))
                                .font(.headline)
                            Text(recording.fileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Duration: \(Int(recording.duration.rounded())) seconds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Button { togglePlayback(for: recording) } label: {
                                    Label(isPlaying(recording) ? "Pause" : "Play", systemImage: isPlaying(recording) ? "pause.fill" : "play.fill")
                                }
                                .buttonStyle(.bordered)

                                Button { cyclePlaybackRate() } label: {
                                    Text(playbackRateLabel)
                                        .font(.caption.weight(.bold))
                                        .frame(minWidth: 42)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Playback speed")
                                .accessibilityValue(playbackRateLabel)
                            }
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
        .onDisappear { stopPlayback() }
    }

    private var playbackRateLabel: String {
        playbackRate == 1 ? "1x" : "\(playbackRate.formatted())x"
    }

    private func isPlaying(_ recording: Recording) -> Bool {
        playingRecordingID == recording.id && player?.isPlaying == true
    }

    private func togglePlayback(for recording: Recording) {
        if isPlaying(recording) {
            player?.pause()
            return
        }

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: recording.url)
            audioPlayer.enableRate = true
            audioPlayer.rate = playbackRate
            audioPlayer.play()
            player = audioPlayer
            playingRecordingID = recording.id
        } catch {
            stopPlayback()
        }
    }

    private func cyclePlaybackRate() {
        let currentIndex = playbackRates.firstIndex(of: playbackRate) ?? 0
        playbackRate = playbackRates[(currentIndex + 1) % playbackRates.count]
        player?.enableRate = true
        player?.rate = playbackRate
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        playingRecordingID = nil
    }
}
