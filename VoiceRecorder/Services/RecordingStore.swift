import AVFoundation
import Foundation

@MainActor
final class RecordingStore: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var recordings: [Recording] = []
    @Published private(set) var isRecording = false
    @Published private(set) var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var currentPrompt = ""
    private var startedAt: Date?

    override init() {
        super.init()
        loadRecordings()
    }

    func requestPermission() async {
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
        permissionDenied = !granted
    }

    func start(prompt: String) async throws {
        await requestPermission()
        guard !permissionDenied else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = Self.recordingsDirectory.appendingPathComponent(Self.fileName(for: Date()))
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        currentPrompt = prompt
        startedAt = Date()
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.delegate = self
        recorder?.record()
        isRecording = true
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        loadRecordings()
    }

    func exportURLs(for selection: Set<Recording.ID>) -> [URL] {
        let chosen = recordings.filter { selection.contains($0.id) }
        return chosen.isEmpty ? recordings.map(\.url) : chosen.map(\.url)
    }

    private func loadRecordings() {
        try? FileManager.default.createDirectory(at: Self.recordingsDirectory, withIntermediateDirectories: true)
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: Self.recordingsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        recordings = urls
            .filter { $0.pathExtension == "m4a" }
            .map { url in
                let values = try? url.resourceValues(forKeys: [.creationDateKey])
                let createdAt = values?.creationDate ?? Date.distantPast
                let asset = AVURLAsset(url: url)
                let duration = CMTimeGetSeconds(asset.duration)
                return Recording(id: UUID(), url: url, createdAt: createdAt, prompt: "City prompt", duration: duration.isFinite ? duration : 0)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            isRecording = false
            loadRecordings()
        }
    }

    static var recordingsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
    }

    private static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "CityVoice_\(formatter.string(from: date)).m4a"
    }
}
