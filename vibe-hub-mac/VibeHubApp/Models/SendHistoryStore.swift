import Foundation

struct SendHistoryEntry: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let target: String
    let text: String
    let status: String
    let summary: String?
}

@MainActor
final class SendHistoryStore: ObservableObject {
    @Published private(set) var entries: [SendHistoryEntry] = []

    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("VibeHub", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("send-history.json")
        load()
    }

    func append(target: String, text: String, status: String, summary: String? = nil) {
        let entry = SendHistoryEntry(
            id: UUID(),
            createdAt: Date(),
            target: target,
            text: text,
            status: status,
            summary: summary
        )
        entries.insert(entry, at: 0)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([SendHistoryEntry].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL)
    }
}
