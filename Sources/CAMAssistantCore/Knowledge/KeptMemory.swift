import Foundation

public struct KeptMemory: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let answerID: String
    public let text: String
    public let citations: [Citation]
    public let sourceVersionIdentity: String
    public let createdAt: Date
    public let updatedAt: Date
    public let revision: String

    /// Conversation transcripts are deliberately outside the memory model.
    public var conversationTranscript: String? { nil }
}

public enum KeptMemorySaveChoice: Equatable, Sendable {
    case saveSeparately
    case updateExisting(String)
}

public struct KeptMemoryUndoReceipt: Equatable, Sendable {
    public let memoryID: String
    public let expectedRevision: String
    public let previousMemory: KeptMemory?
}

public struct KeptMemoryKeepReceipt: Equatable, Sendable {
    public let memory: KeptMemory
    public let undoReceipt: KeptMemoryUndoReceipt
}

public enum KeptMemoryStoreError: Error, Equatable {
    case uncitedAnswer
    case existingMemoryNotFound
    case staleUndo
}
