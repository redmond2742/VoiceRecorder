import Foundation

struct Recording: Identifiable, Codable, Hashable {
    let id: UUID
    let url: URL
    let createdAt: Date
    let prompt: String
    let duration: TimeInterval

    var fileName: String { url.lastPathComponent }
}
