import Foundation

struct Recording: Identifiable, Codable, Hashable {
    var id: URL { url }
    let url: URL
    let createdAt: Date
    let prompt: String
    let duration: TimeInterval
    let folderName: String

    var fileName: String { url.lastPathComponent }
}

struct RecordingFolder: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let url: URL
}
