import Foundation

/// Atomic local persistence for the small answer-derived memories a user has
/// explicitly chosen to Keep. Source bytes and conversation transcripts are
/// never copied into this store.
public final class KeptMemoryStore {
    private let url: URL
    private let fileManager: FileManager

    public init(url: URL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
    }

    public func all() throws -> [KeptMemory] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode(
            [KeptMemory].self,
            from: Data(contentsOf: url)
        )
        .sorted {
            if $0.updatedAt == $1.updatedAt { return $0.id < $1.id }
            return $0.updatedAt > $1.updatedAt
        }
    }

    public func keep(
        answer: ConversationResponse,
        choice: KeptMemorySaveChoice = .saveSeparately,
        now: Date = Date()
    ) throws -> KeptMemoryKeepReceipt {
        guard !answer.citations.isEmpty else {
            throw KeptMemoryStoreError.uncitedAnswer
        }
        var memories = try all()
        let previous: KeptMemory?
        let memoryID: String
        let createdAt: Date
        switch choice {
        case .saveSeparately:
            previous = nil
            memoryID = UUID().uuidString.lowercased()
            createdAt = now
        case let .updateExisting(id):
            guard let existing = memories.first(where: { $0.id == id }) else {
                throw KeptMemoryStoreError.existingMemoryNotFound
            }
            previous = existing
            memoryID = existing.id
            createdAt = existing.createdAt
            memories.removeAll { $0.id == id }
        }
        let sourceVersionIdentity = Self.sourceVersionIdentity(
            answer.citations
        )
        let revision = Self.digest(
            [
                memoryID,
                answer.id,
                answer.text,
                sourceVersionIdentity,
                String(now.timeIntervalSince1970),
            ].joined(separator: "|")
        )
        let memory = KeptMemory(
            id: memoryID,
            answerID: answer.id,
            text: answer.text.trimmingCharacters(in: .whitespacesAndNewlines),
            citations: answer.citations,
            sourceVersionIdentity: sourceVersionIdentity,
            createdAt: createdAt,
            updatedAt: now,
            revision: revision
        )
        memories.append(memory)
        try save(memories)
        return KeptMemoryKeepReceipt(
            memory: memory,
            undoReceipt: KeptMemoryUndoReceipt(
                memoryID: memory.id,
                expectedRevision: memory.revision,
                previousMemory: previous
            )
        )
    }

    public func discard(answerID _: String) throws {
        // Answers are ephemeral until Keep, so Discard intentionally writes
        // nothing and does not need to identify or mutate a durable record.
    }

    public func undo(receipt: KeptMemoryUndoReceipt) throws {
        var memories = try all()
        guard let current = memories.first(where: {
            $0.id == receipt.memoryID
        }), current.revision == receipt.expectedRevision else {
            throw KeptMemoryStoreError.staleUndo
        }
        memories.removeAll { $0.id == receipt.memoryID }
        if let previous = receipt.previousMemory {
            memories.append(previous)
        }
        try save(memories)
    }

    public func duplicateCandidate(
        for answer: ConversationResponse
    ) throws -> KeptMemory? {
        let proposedTerms = Self.terms(answer.text)
        return try all().first { memory in
            let existingTerms = Self.terms(memory.text)
            guard !proposedTerms.isEmpty, !existingTerms.isEmpty else {
                return false
            }
            let intersection = proposedTerms.intersection(existingTerms).count
            let union = proposedTerms.union(existingTerms).count
            return Double(intersection) / Double(union) >= 0.85
        }
    }

    private func save(_ memories: [KeptMemory]) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(memories.sorted { $0.id < $1.id })
            .write(to: url, options: .atomic)
    }

    private static func sourceVersionIdentity(
        _ citations: [Citation]
    ) -> String {
        digest(
            citations
                .map {
                    "\($0.sourceID)|\($0.passageID)|\($0.quote)"
                }
                .sorted()
                .joined(separator: "\n")
        )
    }

    private static func terms(_ text: String) -> Set<String> {
        Set(
            text.lowercased().split {
                !$0.isLetter && !$0.isNumber
            }.map(String.init)
        )
    }

    private static func digest(_ text: String) -> String {
        GoldenRetrievalManifest.sha256(of: Data(text.utf8))
    }
}
