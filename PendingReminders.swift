import Foundation

struct PendingReminders {
    struct Entry {
        let id: String
        var conversation: String
    }
    private(set) var entries: [Entry] = []
    var count: Int { entries.count }
    var latestID: String? { entries.last?.id }

    mutating func add(_ id: String, conversation: String) {
        guard !entries.contains(where: { $0.id == id }) else { return }
        entries.append(Entry(id: id, conversation: conversation))
        if entries.count > 2000 { entries.removeFirst() }
    }

    mutating func associate(_ id: String, conversation: String) {
        guard !conversation.isEmpty, let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].conversation = conversation
    }

    @discardableResult
    mutating func handle(_ conversation: String) -> Bool {
        guard !conversation.isEmpty else { return false }
        let oldCount = count
        entries.removeAll { $0.conversation == conversation }
        return count != oldCount
    }

    mutating func clear() { entries.removeAll() }
}
