import AVFoundation
import CoreGraphics
import Foundation

@MainActor
final class RecordingStore: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var recordings: [Recording] = []
    @Published private(set) var folders: [RecordingFolder] = []
    @Published private(set) var currentFolderName: String
    @Published private(set) var isRecording = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var audioLevels: [CGFloat] = Array(repeating: 0.08, count: 28)

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var currentPrompt = ""
    private var startedAt: Date?

    override init() {
        currentFolderName = UserDefaults.standard.string(forKey: Keys.currentFolderName) ?? "Default"
        super.init()
        loadRecordings()
    }

    func requestPermission() async {
        let granted = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            } else {
                AVCaptureDevice.requestAccess(for: .audio) { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }
        permissionDenied = !granted
    }

    func setCurrentFolder(_ folderName: String) {
        currentFolderName = sanitizedFolderName(folderName)
        UserDefaults.standard.set(currentFolderName, forKey: Keys.currentFolderName)
        try? FileManager.default.createDirectory(at: url(forFolderNamed: currentFolderName), withIntermediateDirectories: true)
        loadRecordings()
    }

    func createFolder(named name: String) {
        let folderName = sanitizedFolderName(name)
        try? FileManager.default.createDirectory(at: url(forFolderNamed: folderName), withIntermediateDirectories: true)
        setCurrentFolder(folderName)
    }

    func start(prompt: String) async throws {
        await requestPermission()
        guard !permissionDenied else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)

        let folderURL = url(forFolderNamed: currentFolderName)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let url = folderURL.appendingPathComponent(Self.fileName(for: Date()))
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
        recorder?.isMeteringEnabled = true
        recorder?.record()
        isRecording = true
        startMetering()
    }

    func stop() {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        audioLevels = Array(repeating: 0.08, count: 28)
        loadRecordings()
    }

    func exportURLs(for selection: Set<Recording.ID>) -> [URL] {
        let chosen = recordings.filter { selection.contains($0.id) }
        return chosen.isEmpty ? recordings.map(\.url) : chosen.map(\.url)
    }

    func exportURLs(forFolder folder: RecordingFolder?) -> [URL] {
        guard let folder else { return exportURLs(for: []) }
        return recordings.filter { $0.folderName == folder.name }.map(\.url)
    }

    private func startMetering() {
        audioLevels = Array(repeating: 0.08, count: 28)
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                let normalized = Self.normalizedAudioLevel(fromAveragePower: power)
                self.audioLevels.append(normalized)
                if self.audioLevels.count > 28 {
                    self.audioLevels.removeFirst(self.audioLevels.count - 28)
                }
            }
        }
    }

    private static func normalizedAudioLevel(fromAveragePower power: Float) -> CGFloat {
        guard power.isFinite else { return 0.08 }

        let normalized = CGFloat((power + 55) / 55)
        guard normalized.isFinite else { return 0.08 }

        return min(max(normalized, 0.08), 1)
    }

    func deleteRecording(_ recording: Recording) {
        try? FileManager.default.removeItem(at: recording.url)
        loadRecordings()
    }

    func deleteRecordings(at offsets: IndexSet, in folder: RecordingFolder) {
        let folderRecordings = recordings.filter { $0.folderName == folder.name }
        for offset in offsets {
            guard folderRecordings.indices.contains(offset) else { continue }
            try? FileManager.default.removeItem(at: folderRecordings[offset].url)
        }
        loadRecordings()
    }

    func deleteFolder(_ folder: RecordingFolder) {
        try? FileManager.default.removeItem(at: folder.url)
        if currentFolderName == folder.name {
            currentFolderName = "Default"
            UserDefaults.standard.set(currentFolderName, forKey: Keys.currentFolderName)
        }
        loadRecordings()
    }

    private func loadRecordings() {
        Task { await loadRecordingsFromDisk() }
    }

    private func loadRecordingsFromDisk() async {
        try? FileManager.default.createDirectory(at: Self.recordingsDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url(forFolderNamed: currentFolderName).path) {
            try? FileManager.default.createDirectory(at: url(forFolderNamed: currentFolderName), withIntermediateDirectories: true)
        }

        let folderURLs = (try? FileManager.default.contentsOfDirectory(
            at: Self.recordingsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        folders = folderURLs.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return values?.isDirectory == true ? RecordingFolder(name: url.lastPathComponent, url: url) : nil
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if folders.isEmpty {
            createFolder(named: currentFolderName)
            return
        }

        var loadedRecordings: [Recording] = []
        for folder in folders {
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: folder.url,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for url in urls where Self.supportedRecordingExtensions.contains(url.pathExtension.lowercased()) {
                let values = try? url.resourceValues(forKeys: [.creationDateKey])
                let createdAt = values?.creationDate ?? Date.distantPast
                let asset = AVURLAsset(url: url)
                let durationTime = (try? await asset.load(.duration)) ?? .zero
                let duration = CMTimeGetSeconds(durationTime)
                loadedRecordings.append(Recording(url: url, createdAt: createdAt, prompt: "City prompt", duration: duration.isFinite ? duration : 0, folderName: folder.name))
            }
        }

        recordings = loadedRecordings.sorted { $0.createdAt > $1.createdAt }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            isRecording = false
            meterTimer?.invalidate()
            meterTimer = nil
            loadRecordings()
        }
    }

    private func url(forFolderNamed name: String) -> URL {
        Self.recordingsDirectory.appendingPathComponent(sanitizedFolderName(name), isDirectory: true)
    }

    private func sanitizedFolderName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.replacingOccurrences(of: "/", with: "-")
        return safe.isEmpty ? "Default" : safe
    }

    static var recordingsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
    }

    private static let supportedRecordingExtensions: Set<String> = ["m4a", "mp3"]

    private static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "CityVoice_\(formatter.string(from: date)).m4a"
    }

    private enum Keys {
        static let currentFolderName = "currentFolderName"
    }
}
